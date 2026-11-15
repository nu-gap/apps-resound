# 0004. Port unit by unit, each unit small and build-verified

**Date:** 2026-11-02
**Status:** accepted

## Context

The app is a 1998 Rhapsody codebase whose ~28 sources block on different
dependencies: the legacy SoundKit API, the unreadable 1998 nibs (ADR 0008),
the modules' DSP (ADR 0019), the legacy build system (ADR 0005).  A
big-bang migration would produce an unbuildable pile that no one can
verify — the failure mode the nu-gap import exists to avoid.

## Decision

The port proceeds **unit by unit**: each unit is small, build-verified
against the CI stack, and committed on its own.  The order followed:
the `Snd (ResoundSound)` file-I/O category (test-first, ADR 0013/0014),
`SoundManager` (playback + the recording re-route, ADR 0015), the console +
meter/tracker, the view chain, the file unit (the 1998 main model live at
startup, ADR 0016), the SndKit-leftovers (the twelve remaining `CLASSES`
files), the `PreferencesManager` (26/26 of the 1998 application classes in
the build) — with the modules (Phase 3) and packaging still ahead.  A unit
enters the build only with every gate green (ADR 0007) and, for GUI units,
the app launching; a not-yet-ported neighbour is bridged with the smallest
possible local protocol or `id` dispatch, and the bridge is retired the
moment the neighbour unit lands.

## Consequences

- Dozens of green-CI commits, each independently bisectable and
  documented; the `README.md` milestone list is the visible progress.
- Local bridges accumulate technical debt that follow-up units pay back
  (the `ConsoleSoundViewCompat` protocol and the `id`-typed view ivar were
  both retired in the 2026-11-08 view-chain follow-up).
- The unit order is dependency-constrained, not cosmetic: the nib
  conversion preceded the in-app UI, the file unit came last among the app
  files because it wires the whole chain.

## References

- `README.md` — Status milestones, "The GNUstep port".
- `docs/RESOUND_SNDKIT_PLAN.md` — the phase/checklist structure the units
  execute.
