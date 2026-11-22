# 0010. Carry port patches against the pinned dependencies

**Date:** 2026-11-03
**Status:** accepted

## Context

The port pins three third-party codebases: the `third_party/MusicKit`
submodule (ADR 0002), the CI's hermetic GNUstep stack commits (ADR 0006),
and the `gormtool` converter checkout (ADR 0008/0011).  Modern toolchains
(clang 16+), non-x86 architectures, machines with half-duplex audio
devices, and the 1998 code's own ownership assumptions each trip at least
one of them.  And because the 1998 sources must stay byte-identical (ADR
0003), anything a 1998 ownership or format pattern needs has to come from
the framework — not from edits to the app.

## Decision

Small, individually justified port patches live in `patches/`, in three
families — `MusicKit-0001…0006` (six SndKit/MusicKit fixes),
`GNUstep-0002/0003` (gnustep-gui), `Gorm-0001/0002` (apps-gorm) —
each documented in `docs/UPSTREAM_PATCHES.md` with symptom, explanation,
and the proposed fix.  Each patch is **submitted upstream** and is **dropped on the pin bump
that carries it**.  One documented **inversion** of that rule: a patch
whose upstream issue was *closed without merging* stays in the build and
leaves only on a pin bump to a commit that already carries the fix (the
determinism case, ADR 0011).  Application is mechanical and guarded:
`third_party/build-sndkit.sh` applies only the `MusicKit-*` patches (and
refuses to continue if one no longer applies, leaving the submodule
pristine); the CI stack build applies the `GNUstep-*` patches with
`--dry-run` first; the converter patch is a dev-time recipe.  The three
families do not interfere (the build script's filename filter).

## Consequences

- Every pin bump is a patch re-verification; the patch set is the project's
  standing list of framework-level defects its code depends on.
- The patch documents double as the upstream issue bodies (carried
  verbatim), which the maintainers quote back in their replies.
- `GNUSTEP_STACK_REV` is bumped whenever the applied GNUstep patch set
  changes, so the CI cache never serves a stale stack.

## References

- `docs/UPSTREAM_PATCHES.md` — all three families, with upstream status.
