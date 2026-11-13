#!/bin/bash
# native-compat-fix-for-system5-on-apple-silicon — compatibility fix so that an Avid/Euphonix System 5-family console
# works with Pro Tools running natively on Apple Silicon.
#
# This script contains NO Avid software. You provide Avid's official installer
# "EUCON Workstation 2021.6" from your own Avid account; the script extracts the
# EUCON engine (libEuCon2.dylib) from it on your Mac, verifies it, changes the
# bytes listed in patch/manifest-*.txt, re-signs it ad hoc and installs it.
#
# It only uses tools shipped with macOS (no Xcode / Command Line Tools needed).
# Not affiliated with Avid.
#
# Copyright (C) 2026 8ctet
# SPDX-License-Identifier: GPL-3.0-or-later
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version. It is distributed WITHOUT ANY WARRANTY; see the LICENSE file.

set -u

PROJECT="native-compat-fix-for-system5-on-apple-silicon"
VERSION="1.0.0"
HERE="$(cd "$(/usr/bin/dirname "$0")" && pwd)"
MANIFEST="$HERE/patch/manifest-4.7.9-2021.6.1.7.txt"
MANIFEST_SHA256="f3b60fbb0ad9fa23a06beccfacab7c2bc64d5f5be93b61e9d1649eda0b8c9ea6"

# Avid "EUCON Workstation 2021.6.1.7" installer and the engine inside it
DMG_SHA256="5e339350a6f778829db47a6a4c2a3fde021b768c96c742beaeffcd69dc3b71eb"
INPUT_SHA256="87b31da58b84bff56f88a119b7dceb32b8db0d78a7777fe0ab569aaa0a7332a2"
# Result after applying the manifest, BEFORE ad-hoc signing (signing is not deterministic)
PATCHED_UNSIGNED_SHA256="7f179744037ec7d1b8a2c62d829a2b69447fc5686233b487aba7a796f7b3a160"

TARGET="/usr/local/lib/libEuCon2.dylib"
STATE_DIR="/Library/Application Support/$PROJECT"
BACKUP_DIR="$STATE_DIR/backups"
AVID_TEAM_ID="4UYUA773XD"
PT_APP="${PT_APP:-/Applications/Pro Tools.app}"
MC_CLIENT="/Applications/MC_Client.app"
ASSUME_YES=0
TMP=""

# ---------------------------------------------------------------- helpers
say()  { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
ok()   { printf '  [ok] %s\n' "$*"; }
warn() { printf '  [!]  %s\n' "$*"; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

cleanup() {
    if [ -n "$TMP" ] && [ -d "$TMP" ]; then
        [ -d "$TMP/mnt" ] && /usr/bin/hdiutil detach "$TMP/mnt" -quiet -force >/dev/null 2>&1
        case "$TMP" in
            /tmp/s5np.*|/private/tmp/s5np.*|/var/folders/*/s5np.*|/private/var/folders/*/s5np.*) /bin/rm -rf "$TMP" ;;
        esac
    fi
}
trap cleanup EXIT

sha256() {
    local h
    h=$(/usr/bin/shasum -a 256 "$1" 2>/dev/null | /usr/bin/cut -d' ' -f1)
    [ -n "$h" ] || h=$(/usr/bin/openssl dgst -sha256 -r "$1" 2>/dev/null | /usr/bin/cut -c1-64)
    printf '%s' "$h"
}

hex_at() { /usr/bin/od -An -tx1 -v -j "$2" -N "$3" "$1" | /usr/bin/tr -d ' \n'; }

u32be() { local h; h=$(hex_at "$1" "$2" 4); printf '%d' "$((16#$h))"; }

# byte offset of an architecture slice inside a universal (fat) Mach-O file
slice_offset() {   # file arch
    local f="$1" want="$2" n i e cpu
    [ "$(hex_at "$f" 0 4)" = "cafebabe" ] || return 1
    n=$(u32be "$f" 4)
    for ((i = 0; i < n; i++)); do
        e=$((8 + 20 * i))
        cpu=$(hex_at "$f" "$e" 4)
        if { [ "$cpu" = 01000007 ] && [ "$want" = x86_64 ]; } || { [ "$cpu" = 0100000c ] && [ "$want" = arm64 ]; }; then
            u32be "$f" $((e + 8)); return 0
        fi
    done
    return 1
}

write_hex() {   # file offset hex
    local f="$1" off="$2" hex="$3" fmt="" oct i
    for ((i = 0; i < ${#hex}; i += 2)); do
        printf -v oct '%03o' "$((16#${hex:i:2}))"
        fmt="$fmt\\0$oct"
    done
    printf '%b' "$fmt" | /bin/dd of="$f" bs=1 seek="$off" conv=notrunc 2>/dev/null
}

confirm() {
    [ "$ASSUME_YES" = 1 ] && return 0
    [ -t 0 ] || die "not running interactively; re-run with --yes to confirm."
    local ans
    read -r -p "  $1 [y/N] " ans
    case "$ans" in y|Y|yes|YES|o|O|oui|OUI) return 0 ;; *) say "  Cancelled."; exit 1 ;; esac
}

plist_value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null; }

pt_allows_unsigned_libs() {
    /usr/bin/codesign -d --entitlements - --xml "$PT_APP" 2>/dev/null \
        | /usr/bin/tr -d ' \n\t\r' | /usr/bin/grep -q 'disable-library-validation</key><true/>'
}

manifest_ok() {
    [ -f "$MANIFEST" ] || die "manifest not found: $MANIFEST"
    [ "$(sha256 "$MANIFEST")" = "$MANIFEST_SHA256" ] || die "manifest checksum mismatch — the download is incomplete or was modified."
}

# are all manifest runs present in this file? (prints: patched / unpatched)
manifest_state() {
    local f="$1" arch off new base x64 a64
    [ -f "$f" ] || { echo unpatched; return; }
    x64=$(slice_offset "$f" x86_64) && a64=$(slice_offset "$f" arm64) || { echo unpatched; return; }
    while read -r arch off new; do
        case "$arch" in x86_64) base=$x64 ;; arm64) base=$a64 ;; *) continue ;; esac
        [ "$(hex_at "$f" "$((base + off))" "$((${#new} / 2))")" = "$new" ] || { echo unpatched; return; }
    done < "$MANIFEST"
    echo patched
}

describe_engine() {   # file -> human readable identity
    local f="$1" h sig
    [ -f "$f" ] || { echo "not installed"; return; }
    h=$(sha256 "$f")
    case "$h" in
        "$INPUT_SHA256") echo "Avid EUCON engine 4.7.9 (EUCON 2021.6) — unpatched"; return ;;
        37c118b671bda2db8d5570f307a79fc0f9af5acfadf3bb010e48ad1ed17eefb0)
            echo "Avid EUCON engine 5.4.9 (EUCON 2025.6) — stock; does NOT work with System 5"; return ;;
        1795d84338c847bfafc716e279991234b4abdaafec600a1998342f099969c1ca)
            echo "Avid EUCON engine 4.0.1 (2017) — works with System 5 under Rosetta only"; return ;;
    esac
    sig=$(/usr/bin/codesign -dv "$f" 2>&1)
    if printf '%s' "$sig" | /usr/bin/grep -q "TeamIdentifier=$AVID_TEAM_ID"; then
        echo "Avid-signed EUCON engine (version not recognised by this tool)"
    elif [ "$(manifest_state "$f")" = patched ]; then
        echo "PATCHED by $PROJECT (engine 4.7.9, native arm64 + x86_64)"
    else
        echo "modified or unknown engine (not produced by this tool)"
    fi
}

# ---------------------------------------------------------------- build
# build <installer.dmg | installer.pkg | libEuCon2.dylib> <output>
do_build() {
    local input="$1" out="$2" dylib="" pkg h
    manifest_ok
    [ -e "$input" ] || die "file not found: $input"
    TMP=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/s5np.XXXXXX") || die "cannot create a temporary folder"

    case "$input" in
        *.dmg|*.DMG)
            h=$(sha256 "$input")
            if [ "$h" = "$DMG_SHA256" ]; then ok "installer image verified (EUCON Workstation 2021.6.1.7)"
            else warn "installer image checksum differs from the reference — continuing; the engine itself is verified below."; fi
            /bin/mkdir -p "$TMP/mnt"
            /usr/bin/hdiutil attach "$input" -readonly -nobrowse -noverify -noautoopen -mountpoint "$TMP/mnt" >/dev/null 2>&1 \
                || die "could not open the installer image."
            pkg=$(/usr/bin/find "$TMP/mnt" -maxdepth 3 -name '*.pkg' | /usr/bin/head -1)
            [ -n "$pkg" ] || die "no installer package found inside the image."
            ;;
        *.pkg) pkg="$input" ;;
        *.dylib) dylib="$input" ;;
        *) die "expected the EUCON Workstation 2021.6 .dmg (or its .pkg, or libEuCon2.dylib)." ;;
    esac

    if [ -z "$dylib" ]; then
        info "extracting the EUCON engine from Avid's installer (this takes a moment)..."
        /usr/sbin/pkgutil --expand-full "$pkg" "$TMP/x" >/dev/null 2>&1 || die "could not expand the installer package."
        dylib=$(/usr/bin/find "$TMP/x" -path '*/Payload/usr/local/lib/libEuCon2.dylib' | /usr/bin/head -1)
        [ -n "$dylib" ] || die "libEuCon2.dylib not found in this installer."
    fi

    /bin/cp "$dylib" "$TMP/work.dylib"
    [ "$(sha256 "$TMP/work.dylib")" = "$INPUT_SHA256" ] \
        || die "this is not the EUCON 2021.6.1.7 engine (libEuCon2 4.7.9). Download 'EUCON Workstation 2021.6' from your Avid account."
    ok "original engine verified (libEuCon2 4.7.9)"

    info "applying patch..."
    local arch off new base x64 a64 n=0
    x64=$(slice_offset "$TMP/work.dylib" x86_64) && a64=$(slice_offset "$TMP/work.dylib" arm64) \
        || die "unexpected file layout."
    while read -r arch off new; do
        case "$arch" in x86_64) base=$x64 ;; arm64) base=$a64 ;; *) continue ;; esac
        write_hex "$TMP/work.dylib" "$((base + off))" "$new"
        n=$((n + 1))
    done < "$MANIFEST"
    [ "$(sha256 "$TMP/work.dylib")" = "$PATCHED_UNSIGNED_SHA256" ] || die "patched result does not match the reference — aborting, nothing was installed."
    ok "patch applied and verified ($n byte runs)"

    /usr/bin/codesign --force --sign - "$TMP/work.dylib" >/dev/null 2>&1 || die "ad-hoc signing failed."
    /usr/bin/codesign --verify --strict "$TMP/work.dylib" >/dev/null 2>&1 || die "signature verification failed."
    /usr/bin/xattr -c "$TMP/work.dylib" 2>/dev/null
    ok "re-signed (ad hoc) and signature verified"

    # result stays in $TMP/work.dylib; optionally copied out
    if [ -n "$out" ]; then /bin/cp "$TMP/work.dylib" "$out" || die "cannot write $out"; fi
}

# ---------------------------------------------------------------- commands
cmd_status() {
    say "$PROJECT $VERSION — status"
    info "macOS $(/usr/bin/sw_vers -productVersion) on $( [ "$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] && echo 'Apple Silicon' || echo 'Intel')"
    if [ -d "$PT_APP" ]; then
        info "Pro Tools $(plist_value "$PT_APP" CFBundleShortVersionString)"
        if pt_allows_unsigned_libs; then ok "Pro Tools accepts a re-signed engine (disable-library-validation)"
        else warn "this Pro Tools build does NOT accept a re-signed engine — the patch cannot work with it"; fi
    else
        warn "Pro Tools not found at $PT_APP (set PT_APP=/path/to/Pro\\ Tools.app)"
    fi
    if [ -d "$MC_CLIENT" ]; then ok "MC_Client $(plist_value "$MC_CLIENT" CFBundleShortVersionString) present"
    else warn "MC_Client not found — install the current 'EUCON Workstation' from Avid first"; fi
    manifest_ok
    info "engine at $TARGET:"
    info "  $(describe_engine "$TARGET")"
    if [ -d "$BACKUP_DIR" ] && [ -n "$(/bin/ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        info "backups in $BACKUP_DIR:"
        /bin/ls -1t "$BACKUP_DIR" | while read -r b; do info "  $b — $(describe_engine "$BACKUP_DIR/$b")"; done
    fi
}

cmd_build() {
    local input="${1:-}" out="${2:-$PWD/libEuCon2.dylib.patched}"
    [ -n "$input" ] || die "usage: $0 build <EUCON_WorkstationUnifiedInstallMac_2021_6_1_7.dmg> [output]"
    say "Building the patched engine (nothing is installed)"
    do_build "$input" "$out"
    say ""; ok "written to: $out"
}

cmd_install() {
    local input="${1:-}" current stamp
    [ -n "$input" ] || die "usage: $0 install <EUCON_WorkstationUnifiedInstallMac_2021_6_1_7.dmg>"
    say "$PROJECT $VERSION — install"
    say ""
    [ -d "$PT_APP" ] || die "Pro Tools not found at $PT_APP (set PT_APP=/path/to/Pro\\ Tools.app)"
    pt_allows_unsigned_libs || die "this Pro Tools build does not accept a re-signed engine (missing disable-library-validation)."
    ok "Pro Tools $(plist_value "$PT_APP" CFBundleShortVersionString) accepts a re-signed engine"
    [ -d "$MC_CLIENT" ] || die "MC_Client not found. Install the current 'EUCON Workstation' from your Avid account first (it provides MC_Client), then run this again."
    ok "MC_Client present"
    [ -d "/usr/local/lib" ] || die "/usr/local/lib does not exist — install the current 'EUCON Workstation' from Avid first."
    if /usr/bin/pgrep -x "Pro Tools" >/dev/null 2>&1; then die "quit Pro Tools first."; fi
    current=$(describe_engine "$TARGET")
    info "currently installed: $current"
    say ""
    say "  Please read before continuing:"
    say "   - This replaces the EUCON engine used by Pro Tools on this Mac."
    say "   - Current EUCON surfaces (S1, S3, S4, S6, Artist, Dock, Control app) will NOT work"
    say "     with Pro Tools while the patched engine is installed. Use '$0 restore' to undo."
    say "   - Any Avid update (EUCON, Pro Tools, Avid Link) may overwrite it; run '$0 status' after updates."
    say "   - Unofficial and unsupported by Avid. Use at your own risk."
    say ""
    confirm "Continue?"

    do_build "$input" ""

    say ""; info "administrator password required to install into /usr/local/lib:"
    /usr/bin/sudo /bin/mkdir -p "$BACKUP_DIR" || die "cannot create $BACKUP_DIR"
    if [ -f "$TARGET" ] && [ "$(manifest_state "$TARGET")" != patched ]; then
        stamp=$(/bin/date +%Y%m%d-%H%M%S)
        /usr/bin/sudo /bin/cp -p "$TARGET" "$BACKUP_DIR/libEuCon2.dylib.$stamp" || die "backup failed — nothing was changed."
        ok "previous engine backed up to $BACKUP_DIR/libEuCon2.dylib.$stamp"
    fi
    /usr/bin/sudo /usr/bin/install -o root -g wheel -m 0755 "$TMP/work.dylib" "$TARGET" || die "install failed."
    [ "$(manifest_state "$TARGET")" = patched ] || die "post-install check failed."
    ok "patched engine installed at $TARGET"
    say ""
    say "  Next steps:"
    say "   1. Finder > Applications > Pro Tools > Get Info: make sure 'Open using Rosetta' is UNCHECKED."
    say "   2. Launch Pro Tools, enable EUCON, then press Link on the console."
}

cmd_restore() {
    local pick="${1:-}"
    [ -d "$BACKUP_DIR" ] || die "no backup found. To return to stock, reinstall 'EUCON Workstation' from your Avid account."
    if [ -z "$pick" ]; then
        pick=$(/bin/ls -1t "$BACKUP_DIR" 2>/dev/null | /usr/bin/head -1)
        [ -n "$pick" ] || die "no backup found. To return to stock, reinstall 'EUCON Workstation' from your Avid account."
        pick="$BACKUP_DIR/$pick"
    fi
    [ -f "$pick" ] || die "backup not found: $pick"
    if /usr/bin/pgrep -x "Pro Tools" >/dev/null 2>&1; then die "quit Pro Tools first."; fi
    say "Restoring: $pick"
    info "$(describe_engine "$pick")"
    confirm "Restore this engine to $TARGET?"
    /usr/bin/sudo /usr/bin/install -o root -g wheel -m 0755 "$pick" "$TARGET" || die "restore failed."
    ok "restored."
}

usage() {
    cat <<EOF
$PROJECT $VERSION

  bash $(/usr/bin/basename "$0") status
  bash $(/usr/bin/basename "$0") install <EUCON_WorkstationUnifiedInstallMac_2021_6_1_7.dmg> [--yes]
  bash $(/usr/bin/basename "$0") build   <EUCON_WorkstationUnifiedInstallMac_2021_6_1_7.dmg> [output]
  bash $(/usr/bin/basename "$0") restore [backup-file] [--yes]

  status   show what is installed and whether this Mac can use the patch
  install  extract, verify, patch, re-sign and install the engine (asks for your password)
  build    produce the patched engine without installing it (for checking)
  restore  put back the engine that was installed before (latest backup by default)

  Get the installer from your Avid account: EUCON / EUCON Workstation 2021.6 (macOS).
EOF
}

# ---------------------------------------------------------------- main
ARGS=()
for a in "$@"; do
    case "$a" in
        --yes|-y) ASSUME_YES=1 ;;
        *) ARGS+=("$a") ;;
    esac
done
set -- "${ARGS[@]:-}"
case "${1:-}" in
    status|verify)     cmd_status ;;
    install)           shift; cmd_install "${1:-}" ;;
    build)             shift; cmd_build "${1:-}" "${2:-}" ;;
    restore|uninstall) shift; cmd_restore "${1:-}" ;;
    -h|--help|help|"") usage ;;
    --version|version) say "$VERSION" ;;
    *) usage; exit 1 ;;
esac
