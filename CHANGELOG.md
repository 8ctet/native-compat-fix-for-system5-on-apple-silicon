# Changelog

## 1.0.0 — 2026-11-12
- First public release.
- `patcher.sh` with `status`, `install`, `build` and `restore`.
- Patch manifest for the EUCON engine (libEuCon2 4.7.9) shipped in Avid's
  "EUCON Workstation 2021.6.1.7" installer: protocol interface-ID alignment and
  peer-validation correction (568 byte runs, slice-relative offsets, no original
  Avid bytes listed).
- Tested: Avid/Euphonix System 5 (S5 Fusion, SC264D controller, eMix 6.1.0) with
  Pro Tools 25.6.1 running natively on a Mac Studio M4 Max, macOS 15.7.
