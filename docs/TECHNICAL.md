# Technical notes

How a System 5-family console was made to work with Pro Tools running natively on Apple Silicon, and why the patch is what it is. Written for people who want to understand, verify or extend the work.

All findings below come from observing and testing the software on our own machines: packet captures, the engine's own log files, comparisons between engine versions taken from Avid's public installers, and analysis of the engine library. They are described in our own words; no Avid source code or documentation is reproduced here.

---

## 1. Where the EUCON engine lives, and who loads it

- Pro Tools does **not** embed its EUCON engine. Its EUCON plug-in (`Pro Tools.app/Contents/Frameworks/Controllers/EuCon.bundle`) loads **`/usr/local/lib/libEuCon2.dylib`** at run time with `dlopen()`, using that absolute path. It is not a link-time dependency (`otool -L` does not show it), which is why this is easy to miss.
- So **whatever file sits at that path *is* Pro Tools' EUCON engine.** Replacing that one file changes how Pro Tools talks to every EUCON surface on the Mac.
- It is loaded **in-process**, so its architecture must match Pro Tools': an Intel-only engine forces Pro Tools to run under Rosetta.
- **MC_Client** (Avid's EUCON front-end for external workstations, required for a System 5) does not load this file. Replacing the engine does not affect it.
- Pro Tools 25.6.1 runs with the hardened runtime **and** the entitlement `com.apple.security.cs.disable-library-validation` (it needs it to load third-party plug-ins). That is why it accepts an engine re-signed ad hoc. `patcher.sh` checks this entitlement before installing.

Useful diagnostics: Pro Tools writes the engine's own log to `~/Library/Logs/Avid/EuCon/Pro Tools_EuCon.log` (a new file per launch). It states the engine version on its first lines and reports protocol errors and warnings. Reading it would have saved weeks — see [HISTORY.md](HISTORY.md).

## 2. Which engines work with a System 5

Engines were extracted (without installing) from Avid's official installers and tested on the console.

| EUCON release | engine | architectures | System 5 |
|---|---|---|---|
| 2017 | 4.0.1 | x86_64 (+ i386) | ✅ works — Pro Tools under Rosetta only |
| 2020.6 | 4.6.2 | x86_64 | ❌ |
| **2021.6** | **4.7.9** | **x86_64 + arm64** (first universal build) | ❌ unpatched — ✅ **with this patch** |
| 2021.10 | 4.8.3 | universal | ❌ |
| 2022.4 / 2022.9 | 4.8.6 | universal | ❌ (not tested on the console) |
| 2022.12 | 4.10.3 | universal | ❌ |
| 2023.11 | 4.17.2 | universal | ❌ (also under Rosetta) |
| 2025.6 | 5.4.9 | universal | ❌ (also under Rosetta) |

A failing engine also fails under Rosetta, so the problem is a **protocol** change, not an architecture one. Compatibility was lost between 4.0.1 and 4.6.2 — before Apple Silicon existed — so no unmodified universal engine supports the console.

## 3. Fix #1 — the protocol interface ID

**Symptom.** With a 4.6.2+ engine the console never links. The engine log repeats:

```
ReceiveAndHandlePackets: ... Unmarshall error InvalidTypeID (2), packet level 3, interface ID 3082016141000, method index 24 ...
```

**Cause.** Every EUCON remote call carries a 64-bit **interface ID** at offset `0x30` of the packet. When the engine unmarshals a call on its node interface (`SDOF_EuNode::UnmarshallMethod`), it compares that field with a single hard-coded constant and rejects the call on mismatch, *before* looking at which method is being called.

That constant is simply the date the interface definition was last edited, written as decimal digits:

| constant | decimal | reads as | used by |
|---|---|---|---|
| `0x000002CD967A2EC8` | 3082016141000 | 03/08/**2016** 14:10:00 | engine 4.0.1 — and the System 5 |
| `0x0000001C4534EED0` | 121420181200 | 12/14/**2018** 12:00 | engines 4.6.2, 4.7.9 |
| `0x00000010C4BD3600` | 72020211200 | 07/20/**2021** 12:00 | engines 4.8.3 and later |

(The node-browser interface uses `0x02CD967A2F2C` = 03/08/2016 14:11:00 in all of them; it never changed.)

**Why rewriting it is safe on 4.7.9.** Between the 2016 and 2018 versions of that interface, two methods were **appended at the end** of the method table (`RemoteChangeVisibilityFromSurface` and `RemoteViaNodeControlUnassignThisRemoteSurfaceControlOneWay`). The first 137 methods — everything a 2016 console can call — keep the same names and the same order. So restoring the 2016 constant lets the console's calls be accepted and dispatched to the right methods. The two newer methods are simply never called by the console.

**Why only 4.7.9.** From 4.8.3 on, two methods were **removed from the middle** of the table (`RemoteViaNodeSurfaceAssignProcessorToThisSurfaceOneShot` and `RemoteViaNodeSurfaceTransferAttributesToSurface`), which shifts every later method number. Changing the constant alone would route calls to the wrong methods. 4.6.2 has the same table as 4.7.9 but is Intel-only. **4.7.9 is therefore the only universal engine this approach can use.**

**Where it is patched.** The constant appears as an 8-byte literal (x86_64: 142 places — the outgoing-call stubs that stamp it on packets, the identity accessor, the comparison, a static copy) and, on arm64, as `MOVZ`/`MOVK`/`MOVK` instruction triplets (141) plus one 8-byte literal. All of them are rewritten, so the engine both accepts and sends the 2016 value. On arm64 each instruction's destination register is preserved and only three consecutive instructions writing the same register are changed.

With fix #1 alone: the console links, the track list appears, tracks assign, console faders drive Pro Tools, and mute, solo and track names follow Pro Tools — **but Pro Tools cannot move the motorised faders.**

## 4. Fix #2 — peer validation

**Symptom.** With fix #1 only, the engine log shows, right after the value tables are sent to the console:

```
WARN  ProcessRemoteAttributeChange(), remote peer no longer exists      (x110, ~2 ms apart)
```

On the wire, the engine pushes value updates to only ~30 controls (small values such as 0/1/5) instead of ~120 with Avid's 4.0.1 engine; every control with a large value range (faders, …) goes silent.

**Cause.** `ImplEuObject::ProcessRemoteAttributeChange` calls `ImplEuObject::validatePeerExists(unsigned, unsigned, unsigned) const` with three fields taken from the incoming message. When it returns false, the engine logs the warning above and discards the change. This check belongs to peer bookkeeping that changed in the 2018 interface generation, and its lookup fails for a 2016-era console.

**Fix.** `validatePeerExists` is made to return `true` (x86_64: `mov eax,1 ; ret`; arm64: `mov w0,#1 ; ret`). The code that runs when the check passes only copies fields out of the incoming message — it does not use a peer object returned by the lookup — so forcing the result does not lead to an invalid memory access.

With both fixes, everything works in both directions, including motorised faders. (We have not traced exactly how this check also gates the outgoing updates; the result was verified on the console.)

## 5. How the patch is built and verified

- [`tools/make_manifest.py`](../tools/make_manifest.py) (maintainer tool, needs Xcode Command Line Tools) reads Avid's original `libEuCon2.dylib` 4.7.9 (SHA-256 `87b31da5…`), applies both corrections to each architecture slice of the universal file, and writes the list of byte runs to [`patch/`](../patch/): **architecture, offset within that slice, replacement bytes** — 568 runs, 1,859 bytes. The original bytes are not listed: the whole input file is verified by SHA-256 instead.
- Offsets are relative to each slice because `codesign` re-lays out a universal file when it re-signs it (the arm64 slice moves), so absolute offsets would not survive signing. `patcher.sh` reads the slice positions from the file's universal header with `od`.
- [`patcher.sh`](../patcher.sh) writes those runs with `od` and `dd` only, then checks the result against a reference SHA-256 (`7f179744…`) **before** signing. An ad-hoc signature is not deterministic (signing the same file twice gives two different files), so the final file's hash cannot be published; the pre-signature hash and `codesign --verify --strict` are used instead. Re-signing is required by macOS after any change to a Mach-O binary; only ad-hoc signing on the user's own machine is performed, and Avid's embedded copyright notices are left untouched.
- The engine produced this way was compared with the engine validated on the console: after removing signatures, **both architecture slices are byte-for-byte identical**.
- `patcher.sh` uses only tools shipped with macOS. `lipo`, `otool`, `nm` and `python3` are deliberately avoided: on a Mac without Xcode Command Line Tools they are stubs that ask to install them.

## 6. Known open points

- During one session the engine logged `EUCON: sequence number mismatch: got 1, expected 455` once. No visible effect.
- Pro Tools crashed once when quitting during testing; it did not happen again after restarting the console and the Mac, and could not be reproduced. If you see crashes on quit, please report them (without attaching the crash file).
- Only one console configuration has been tested (see the README).

## 7. Ideas for later

- Support other inputs (e.g. the 4.6.2 engine for Intel Macs) by generating more manifests.
- A small signed and notarised app around the script, if there is demand.
