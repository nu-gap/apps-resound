# 0002. Pin SndKit to the recent git tip, as a submodule

**Date:** 2026-11-03
**Status:** accepted

## Context

The user's Phase-0 question (2026-11-02): which SndKit do future versions
of Resound use — for the Mac OS X Server 1.2 / Rhapsody target, the GNUstep
target, and the modern macOS future version?  MusicKit (the SndKit
distribution) is actively maintained, but it has no regular release cadence;
the useful GNUstep fixes live on the git master tip.  At pin time the tip
was `9683c76a` (2026-02-22, an actively maintained GNUstep-fixes tip).

## Decision

Use the recent git version of SndKit (`leighsmith/MusicKit` master),
vendored as the **pinned `third_party/MusicKit` git submodule** — the pin is
the commit recorded in the index.  Updating SndKit means bumping the
submodule, after which the port patches in `patches/` must be re-checked
against the new tip: `third_party/build-sndkit.sh` refuses to continue if a
patch no longer applies, so a stale pin fails loudly.  Resound needs only
two of the four MusicKit frameworks — `MKPerformSndMIDI` (portaudio
backend) and `SndKit`; the synthesizer half (`MKDSP`/`MusicKit`) is not
built.

## Consequences

- The pin is a moving target by policy: every bump is a two-step change
  (submodule commit + patch re-verification), with the build script as the
  guard.
- The unused MIDI half of the backend still needs `libportmidi-dev` for
  its headers, so it stays a system prerequisite.
- The frameworks are installed into the active GNUstep prefix both as
  `*.framework` and as flat `libSndKit.so` + headers, so application
  makefiles link with plain `-lSndKit` (see `docs/GNUSTEP_BUILD.md` § SndKit).
- The submodule's working tree shows the applied patches and build
  artifacts after a build — expected; the pristine state is restorable.

## References

- `docs/RESOUND_SNDKIT_PLAN.md` — Phase 0, the two user DECISION items.
- `docs/GNUSTEP_BUILD.md` — § SndKit, the build-and-install recipe.
