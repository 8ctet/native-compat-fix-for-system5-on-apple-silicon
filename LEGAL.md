# Legal notice

🇫🇷 [Version française](LEGAL.fr.md)

## Disclaimer and trademark notice

**Independent project.** native-compat-fix-for-system5-on-apple-silicon is an independent, free, non-commercial project. It is not affiliated with, endorsed, sponsored or supported by Avid Technology, Inc. or any of its subsidiaries.

**Trademarks.** Avid, Pro Tools, EUCON, EuControl, Euphonix and System 5 are trademarks or registered trademarks of Avid Technology, Inc. or its subsidiaries in the United States and/or other countries. They are used here only to identify the products this tool is designed to work with. All other trademarks are the property of their respective owners.

**No Avid software is distributed.** This repository contains no Avid binary, installer, library, documentation or source code. The script works only on a copy of the EUCON Workstation installer that you have downloaded yourself from your own Avid account under Avid's licence terms. It verifies that file's SHA-256 checksum and refuses any other version. It keeps a backup of the original component and provides a command to restore it.

**Purpose.** The sole purpose of this tool is to let lawful licensees restore interoperability between their own System 5 console and EUCON-enabled software on Apple Silicon Macs. It does this by correcting, on their own machine and in their own copy, the behaviour that prevents that interoperability. It does not touch, and must not be used to circumvent, any licensing, activation, authorisation or iLok mechanism.

**Your responsibility.** You are responsible for making sure that modifying your own copy is permitted by the law of your country and by the licence terms that apply to you. In the European Union the relevant provisions include Articles 5 and 6 of Directive 2009/24/EC (in France, Article L.122-6-1 of the Code de la propriété intellectuelle). Use of this tool outside what the law permits may constitute copyright infringement and may be subject to civil or criminal penalties. Modifying an Avid component may void Avid's support for that component.

**No warranty.** This software is provided "as is", without warranty of any kind, express or implied. Use it at your own risk. Nothing in this repository is legal advice.

**Rights holders.** If you hold rights in any material referred to here and have a concern, please contact **contact@8ctet.fr** before sending a formal notice. Good-faith concerns will be reviewed promptly.

## Why this correction exists

These facts are stated so that the purpose of the tool is clear.

- Avid's current EUCON compatibility information no longer lists the System 5 family, and Avid offers no update that lets these consoles work with EUCON engines that run natively on Apple Silicon.
- The engine shipped in EUCON Workstation 2021.6 still implements every remote operation a System 5 uses: the first 137 operations of its node interface keep the same names and order as in the 2016 engine that works with the console. It rejects the console only because a protocol version stamp — a date — no longer matches.
- A peer-validation step in the same engine then discards valid control changes coming from the console, which prevents Pro Tools from moving the motorised faders.
- Each user applies the correction to their own copy, obtained from Avid under Avid's terms. Nothing from Avid is redistributed, and nothing related to licensing, activation or copy protection is changed.

## Framing

The changes are described throughout this project as a *compatibility patch*: a *protocol interface-ID alignment* and a *peer-validation correction*. They are not, and must not be presented as, a way to obtain any Avid product or feature you are not licensed to use.
