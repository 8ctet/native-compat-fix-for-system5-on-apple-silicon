# native-compat-fix-for-system5-on-apple-silicon

A compatibility patch that lets an **Avid / Euphonix System 5-family console** work with **Pro Tools running natively on Apple Silicon Macs** — full two-way EUCON control, without Rosetta.

> **Independent, free, non-commercial project — not affiliated with, endorsed or supported by Avid Technology, Inc.**
> **No Avid software is distributed here.** You download Avid's installer from your own Avid account; the script corrects your own copy on your own Mac. Read [LEGAL.md](LEGAL.md) before use.

🇫🇷 [Version française](README.fr.md)

---

## The problem

On a current Mac, a System 5 appears in the console's list of EUCON workstations, but **Link never completes** (the button keeps blinking) and Pro Tools reports EUCON errors.

The cause is the EUCON engine — the file `/usr/local/lib/libEuCon2.dylib` that Pro Tools loads. Recent EUCON releases install an engine that no longer accepts the messages a System 5 sends. The last engine that works unmodified (2017) contains only Intel code, so Pro Tools has to run under Rosetta.

## What this fix does

It takes the engine from Avid's **EUCON Workstation 2021.6** installer — the first release containing Apple Silicon code — and corrects **two behaviours** that stop it from working with a System 5:

1. a protocol version check that rejects the console's messages (protocol interface-ID alignment);
2. a peer-validation step that wrongly discards the console's control changes — without this correction, Pro Tools cannot move the motorised faders.

How it works: [docs/TECHNICAL.md](docs/TECHNICAL.md). How it was found: [docs/HISTORY.md](docs/HISTORY.md).

## Tested configuration

| | |
|---|---|
| Console | Avid / Euphonix System 5 (S5 Fusion), SC264D controller, eMix 6.1.0 |
| Mac | Mac Studio M4 Max (Apple Silicon), macOS 15.7 Sequoia |
| Pro Tools | 25.6.1, running **natively** |
| EUCON front-end | MC_Client 2025.6 (from the current EUCON Workstation install) |
| Result | console links, Pro Tools track list on the console, tracks assign to faders, **faders work both ways** (motors included), mute / solo / track names follow |

**Not tested yet:** other System 5 variants (S5-MC, MC Pro, Hybrid), other eMix versions, other Pro Tools versions, Intel Macs. Reports are welcome — see *Contributing*.

## Before you start

- **This replaces the EUCON engine used by Pro Tools on this Mac.** While it is installed, **current EUCON surfaces** (S1, S3, S4, S6, Artist series, Dock, Control app) will **not** work with Pro Tools on this Mac. `restore` undoes it.
- **Avid updates may replace it** (EUCON, Pro Tools, Avid Link). Run `status` after any update and run `install` again if needed.
- It is **unofficial and unsupported**. The tool backs up your current engine before installing, and `restore` puts it back.

## What you need

1. A Mac with **Pro Tools**. The tool checks that your Pro Tools build can load a re-signed engine (Pro Tools 25.6.1 can).
2. The **current EUCON Workstation**, installed from your Avid account (it provides **MC_Client**, which the console needs).
3. The **EUCON Workstation 2021.6** installer for macOS, downloaded **from your own Avid account** — file `EUCON_WorkstationUnifiedInstallMac_2021_6_1_7.dmg` (Avid's download portal lists it with the other EUCON / EuControl releases). **Do not install it** — the tool only reads the engine out of it.

No Xcode, Homebrew or Python needed: the script only uses tools that ship with macOS.

## Install

1. Download the latest [release](../../releases) and unzip it.
2. Quit Pro Tools.
3. Open **Terminal**, go to the unzipped folder and check your Mac:
   ```bash
   cd ~/Downloads/native-compat-fix-for-system5-on-apple-silicon-1.0.0
   bash patcher.sh status
   ```
4. Install — you will be asked to confirm, then for your Mac password:
   ```bash
   bash patcher.sh install ~/Downloads/EUCON_WorkstationUnifiedInstallMac_2021_6_1_7.dmg
   ```
5. In Finder › Applications, select **Pro Tools** › *Get Info*, and make sure **“Open using Rosetta” is unchecked**.
6. Launch Pro Tools, enable EUCON, and press **Link** on the console.

## Undo

```bash
bash patcher.sh restore
```
Puts back the engine that was installed before. Reinstalling the current EUCON Workstation from Avid also brings back Avid's stock engine.

## Check without installing

```bash
bash patcher.sh build ~/Downloads/EUCON_WorkstationUnifiedInstallMac_2021_6_1_7.dmg ~/Desktop/libEuCon2.dylib.patched
```
Produces the corrected engine without touching your system.

## Safety

- The installer image and the engine inside it are **checked by SHA-256**; any other version is refused.
- After the correction, the result is checked against a **reference SHA-256** before signing; the signature is then verified.
- Your current engine is **backed up** to `/Library/Application Support/native-compat-fix-for-system5-on-apple-silicon/backups/` before anything is replaced.
- Every byte written is listed in [`patch/`](patch/) (position and new value); [`tools/make_manifest.py`](tools/make_manifest.py) shows how that list was produced.
- The script is about 300 lines of plain Bash. Please read it before running it with administrator rights.

## Troubleshooting

- **“this is not the EUCON 2021.6.1.7 engine”** — a different installer was given. You need exactly *EUCON Workstation 2021.6* (`…2021_6_1_7.dmg`).
- **“Pro Tools … does not accept a re-signed engine”** — your Pro Tools build cannot load a re-signed engine; this fix cannot work with it.
- **The console still blinks after installing** — check that Pro Tools is *not* set to *Open using Rosetta* and is the frontmost application, then run `bash patcher.sh status`.
- **A console module stops responding** — restart the console modules, the console computer and the Mac. (During testing, one module's touch sensing stopped after many reconnections; Avid's unmodified engine did the same, and a full restart fixed it.)

## Contributing

Reports from other consoles, eMix versions, Pro Tools versions and Intel Macs are very welcome. Open an issue with: console model and eMix version, Mac model, macOS version, Pro Tools version, and the output of `bash patcher.sh status`.
**Please never attach Avid files, installers, crash reports or network captures** — they can contain Avid code or your personal identifiers.

## Legal

See **[LEGAL.md](LEGAL.md)** — disclaimer, purpose, your responsibility, and a contact for rights holders.

*Avid, Pro Tools, EUCON, EuControl, Euphonix and System 5 are trademarks or registered trademarks of Avid Technology, Inc. or its subsidiaries, used here only to identify the products this tool works with.*

## Credits

Research, testing and correction by **8ctet**, with Claude (Anthropic) as an AI assistant.

## Licence of this repository

Copyright © 2026 8ctet. Licensed under the **GNU General Public License v3.0 or later** — see [LICENSE](LICENSE).

You may use, study, share and modify these files, including in a professional studio. Anyone who distributes them, modified or not, must do so under the same licence and provide the source code. The licence covers only the files in this repository and grants no rights whatsoever in any Avid software.
