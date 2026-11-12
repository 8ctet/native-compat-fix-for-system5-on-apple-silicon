# How this was found

A short account of how a System 5 was brought back to life on an Apple Silicon Mac — wrong turns included, because they are the most useful part for anyone facing a similar problem with legacy hardware. The final correction is explained in [TECHNICAL.md](TECHNICAL.md).

The work was done by the console's owner, with Claude (Anthropic) as an AI assistant, over a few weeks of sessions.

---

## The situation

A post-production studio replaced an Intel Mac with a Mac Studio M4 Max. The System 5 (S5 Fusion, eMix 6.1.0) had worked for years with Pro Tools on the Intel Mac. On the new Mac, with current Pro Tools and EUCON:

- the Mac appeared in the console's list of workstations;
- pressing **Link** made the button blink, then give up;
- Pro Tools' EUCON indicator turned red with time-out errors.

The System 5 family no longer appears in Avid's current EUCON compatibility information.

## Ruling out the obvious

- **Network:** the Mac's EUCON port was on the wrong subnet. Discovery still worked, so this was easy to miss; fixing it brought the connections up — and revealed the real problem underneath.
- **Rosetta:** running Pro Tools under Rosetta changed nothing.
- **HUI over MIDI:** not an option — the console's MIDI bridge speaks a different protocol from the one Pro Tools accepts.
- **Older Pro Tools:** the versions that officially supported the console do not run on current macOS.

## Watching the conversation

Network captures showed the new Mac sending data to the console and the console never answering. The old Intel Mac provided the decisive reference: a capture of a working session there showed the same console answering fully. The console was fine; something had changed on the Mac side.

A long detour followed — trying to build our own application in between the console and Pro Tools. It got the console to attach, never to complete the link, and is not part of the solution. Several confident explanations (configuration files, which application had focus, keep-alive messages, metering) were tested and turned out to be wrong.

## The log file

The breakthrough came from a file nobody had looked at: the EUCON engine writes its own log under `~/Library/Logs/Avid/EuCon/`. With the current engine it reported, again and again, that it could not decode the messages it was receiving — an **invalid type ID**. The engine itself was rejecting the console.

## First solution: the old engine, under Rosetta

Pro Tools turned out to load its EUCON engine from one file, `/usr/local/lib/libEuCon2.dylib`, at run time (it does not show up among its link-time dependencies, which is why we had first concluded the opposite). Putting the engine from the old Intel Mac in that place, with Pro Tools under Rosetta, made **everything work**, both ways, with no extra software. The only limitation: that engine has no Apple Silicon code.

## Looking for a native engine

The engines from every EUCON installer since 2018 were extracted (without installing them) and tried. The first one with Apple Silicon code dates from 2021 — and none of them worked, natively or under Rosetta. Compatibility had been lost before Apple Silicon existed.

Looking at where the engine rejects the console showed a single version check against a constant that is simply a **date**: 8 March 2016 for the console, 14 December 2018 for the 2021 engine. Comparing engine versions showed that the 2018 change only *added* operations at the end of the list, while later versions *removed* some in the middle. So the 2021.6 engine was the one where restoring the 2016 date was safe. With that correction, the console linked **natively**.

## The motors

Mute, solo and track names followed Pro Tools — but Pro Tools could not move the motorised faders. More explanations were tested and discarded, including one that only fell after we realised we had been inspecting the wrong one of several network connections. Two controlled comparisons narrowed it down: an earlier engine with the same correction behaved exactly the same, and only controls with a wide range of values (the faders) were affected.

## The log file, again

The engine's log for those sessions repeated one warning more than a hundred times: a peer check was rejecting the console's messages and discarding them. Making that check accept the console was a six-byte change — and with it, **everything works natively in both directions, motors included.**

## Lessons

1. **Read the software's own logs first.** Twice, the answer was in a log file while we were busy analysing network traffic.
2. **Trust experiments over explanations.** Many convincing theories were wrong; simple controlled tests settled every question.
3. **"Not linked" does not mean "not used"** — software can load a library at run time.
4. **Keep a known-good reference.** The old Intel Mac made every comparison possible.
5. **Change one thing at a time**, and compare like with like.
6. **Measure the right thing** — a protocol can use several connections at once.
7. **Make the result checkable.** The tool verifies everything it touches and lists every byte it writes, so it can be audited rather than trusted.
