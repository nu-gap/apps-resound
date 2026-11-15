# 0001. Replace the defunct SoundKit with SndKit

**Date:** 2026-11-02
**Status:** accepted

## Context

Resound 3.0 is Sean Luke's sound editor for Rhapsody, written against the
NeXT `SoundKit.framework`.  SoundKit is defunct and no longer available in
any form: no GNUstep path, no modern macOS path, no future extension
capability.  The nu-gap import exists precisely for future GNUstep work, so
the audio core has to move to something alive.

The evaluation of 2026-11-02 (`docs/RESOUND_SNDKIT_PLAN.md`, §1 and §7)
weighed two options.  **Option A** keeps the SoundKit-based codebase for
Rhapsody-only historical preservation: zero audio-core effort, but the
development freezes at a platform whose framework no longer exists.
**Option B** moves the whole codebase to [SndKit](https://github.com/leighsmith/MusicKit)
(MusicKit), the designated open-source successor of the NeXT SoundKit: its
OO design mirrors what Resound was written against (`Snd`/`SndView`/
`SndFormat`/`SndPerformance` ≈ `Sound`/`SoundView`/`SNDSoundStruct`/…), it
retains a C-level compatibility layer (`SndSoundError`, `SND_ERR_*`,
`SndSwap*`, `SND_FORMAT_*`, …), it already targets the required platform
matrix (GNUstep via portaudio, MacOS X / X Server via CoreAudio), and the
capabilities Resound needs (file I/O, conversion, metering,
playback/recording, faders) already exist.

## Decision

Option B: the whole codebase moves to SndKit.  This is an *API migration*
of the same architecture, not a rewrite onto an unrelated framework.  The
original SoundKit implementation stays preserved in `original-archive/` and
in the upstream history, so Option B functionally subsumes Option A.

## Consequences

- The migration is large (~30 app files plus the ten modules, the build
  system, the nibs, the DSP loops, the metering): it proceeds unit by unit
  (ADR 0004) over the course of the port.
- SndKit's semantics differ from SoundKit's at several mapping points
  (performance-based playback/recording, fader-based volume/mute,
  libsndfile-backed files, `NSString` info instead of the
  `SNDSoundStruct` hack): every behaviour change must be called out where
  it happens (ADR 0003), and the deliberate divergences are documented in
  `docs/RESOUND_SNDKIT_PLAN.md` §2.3.
- SndKit's own CoreAudio backend is ~2000-vintage and may itself need
  maintenance for modern macOS — the plan's main open risk.
- The port never diverges from the 1998 design where SndKit offers an
  equivalent; where SndKit *cannot* offer one, the gap is either bridged
  (ADR 0015) or recorded as a behaviour difference.

## References

- `docs/RESOUND_SNDKIT_PLAN.md` — §1 verdict, §2 API assessment, §7 the
  Option A / Option B analysis.
- `README.md` — the SndKit milestone.
