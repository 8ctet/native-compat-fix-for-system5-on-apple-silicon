#!/usr/bin/env python3
# Copyright (C) 2026 8ctet
# SPDX-License-Identifier: GPL-3.0-or-later
"""MAINTAINER TOOL — derives patch/manifest-*.txt from Avid's original libEuCon2.dylib.

End users never run this (it needs Xcode Command Line Tools for `lipo`/`nm`).
It is published so anyone can audit and reproduce exactly how the manifest was built.

Input : libEuCon2.dylib 4.7.9 extracted from Avid's official installer
        EUCON_WorkstationUnifiedInstallMac_2021_6_1_7.dmg
        (EuCon.pkg/Payload/usr/local/lib/libEuCon2.dylib).
Output: a manifest of byte runs: architecture, offset relative to that slice,
        replacement bytes. No original Avid bytes are published —
        the installer verifies the whole input file by SHA-256 instead.

Two changes are derived, per architecture slice:
 1. Protocol interface ID: the 2018 IDL datestamp 0x0000001C4534EED0 is replaced by the
    2016 value 0x000002CD967A2EC8 that System 5-era consoles send.
      - x86_64: every 8-byte little-endian occurrence.
      - arm64 : every MOVZ/MOVK/MOVK triplet materialising the constant (destination
                register preserved, only three consecutive instructions with the same
                register), plus every 8-byte literal occurrence.
 2. ImplEuObject::validatePeerExists(unsigned, unsigned, unsigned) const is made to
    return true (x86_64: mov eax,1; ret — arm64: mov w0,#1; ret).
"""
import struct, subprocess, sys, os, tempfile

OLD, NEW = 0x0000001C4534EED0, 0x000002CD967A2EC8
STUB = {0x01000007: bytes.fromhex('b801000000c3'),       # CPU_TYPE_X86_64
        0x0100000C: bytes.fromhex('20008052c0035fd6')}   # CPU_TYPE_ARM64
ARCH = {0x01000007: 'x86_64', 0x0100000C: 'arm64'}
SYMBOL = '__ZNK12ImplEuObject18validatePeerExistsEjjj'

def movz(imm, hw): return 0xD2800000 | (hw << 21) | (imm << 5)
def movk(imm, hw): return 0xF2800000 | (hw << 21) | (imm << 5)
def triplet(v):    return [movz(v & 0xFFFF, 0), movk((v >> 16) & 0xFFFF, 1), movk((v >> 32) & 0xFFFF, 2)]

def fat_slices(d):
    magic, n = struct.unpack_from('>II', d, 0)
    if magic != 0xCAFEBABE: sys.exit('not a fat (universal) Mach-O')
    out = []
    for i in range(n):
        cpu, sub, off, size, align = struct.unpack_from('>IIIII', d, 8 + 20 * i)
        out.append((cpu, off, size))
    return out

def vm_to_off(sl, vm):
    ncmds, = struct.unpack_from('<I', sl, 16); p = 32
    for _ in range(ncmds):
        cmd, sz = struct.unpack_from('<II', sl, p)
        if cmd == 0x19:  # LC_SEGMENT_64
            vmaddr, vmsize, fileoff, filesize = struct.unpack_from('<QQQQ', sl, p + 24)
            if vmaddr <= vm < vmaddr + vmsize: return fileoff + (vm - vmaddr)
        p += sz
    sys.exit(f'vmaddr 0x{vm:x} not mapped')

def symbol_vmaddr(sl, arch):
    with tempfile.NamedTemporaryFile(suffix='.dylib', delete=False) as t:
        t.write(sl); path = t.name
    try:
        out = subprocess.run(['nm', '-arch', arch, path], capture_output=True, text=True, check=True).stdout
    finally:
        os.unlink(path)
    for line in out.splitlines():
        if line.endswith(' ' + SYMBOL): return int(line.split()[0], 16)
    sys.exit(f'{SYMBOL} not found in {arch} slice')

def main(src, manifest_out, patched_out):
    data = bytearray(open(src, 'rb').read())
    orig = bytes(data)
    stats = []
    for cpu, base, size in fat_slices(orig):
        arch = ARCH.get(cpu)
        if not arch: sys.exit(f'unexpected cputype 0x{cpu:x}')
        sl = bytearray(orig[base:base + size])
        lits = trips = 0
        o, n = struct.pack('<Q', OLD), struct.pack('<Q', NEW)
        i = sl.find(o)
        while i >= 0:
            sl[i:i + 8] = n; lits += 1; i = sl.find(o, i + 8)
        if arch == 'arm64':
            ot, nt = triplet(OLD), triplet(NEW)
            for i in range(0, len(sl) - 12, 4):
                ws = [struct.unpack_from('<I', sl, i + 4 * k)[0] for k in range(3)]
                rd = ws[0] & 0x1F
                if all((ws[k] & ~0x1F) == ot[k] for k in range(3)) and all((w & 0x1F) == rd for w in ws):
                    for k in range(3): struct.pack_into('<I', sl, i + 4 * k, nt[k] | rd)
                    trips += 1
        off = vm_to_off(sl, symbol_vmaddr(bytes(orig[base:base + size]), arch))
        sl[off:off + len(STUB[cpu])] = STUB[cpu]
        data[base:base + size] = sl
        stats.append(f'{arch}: {lits} literal(s), {trips} triplet(s), validatePeerExists @ slice+0x{off:x}')
    # diff -> merged runs, per architecture slice, offsets RELATIVE to the slice
    # (codesign re-lays out the universal file, so absolute offsets do not survive signing)
    runs = []
    for cpu, base, size in fat_slices(orig):
        a, b = orig[base:base + size], bytes(data[base:base + size])
        i = 0
        while i < size:
            if a[i] != b[i]:
                j = i
                while j < size and a[j] != b[j]: j += 1
                runs.append((ARCH[cpu], i, b[i:j])); i = j
            else:
                i += 1
    with open(manifest_out, 'w') as f:
        f.write('# Patch manifest — one byte run per line: <arch> <offset-in-slice> <replacement-hex>\n')
        f.write('# Offsets are relative to the start of each architecture slice of the universal\n')
        f.write('# libEuCon2.dylib 4.7.9 shipped in EUCON Workstation 2021.6.1.7\n')
        f.write('# (input SHA-256 87b31da58b84bff56f88a119b7dceb32b8db0d78a7777fe0ab569aaa0a7332a2).\n')
        f.write('# No original bytes are listed. Generated by tools/make_manifest.py.\n')
        for st in stats: f.write(f'# {st}\n')
        for arch, off, b in runs: f.write(f'{arch} {off} {b.hex()}\n')
    open(patched_out, 'wb').write(bytes(data))
    print('\n'.join(stats)); print(f'{len(runs)} byte runs, {sum(len(b) for _, _, b in runs)} bytes changed')

if __name__ == '__main__':
    if len(sys.argv) != 4: sys.exit('usage: make_manifest.py <original libEuCon2.dylib> <manifest.txt> <patched-unsigned.dylib>')
    main(*sys.argv[1:])
