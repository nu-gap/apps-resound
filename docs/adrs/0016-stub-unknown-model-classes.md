# 0016. Stub the classes the 1998 main model instantiates

**Date:** 2026-11-10
**Status:** accepted

## Context

The file unit (FU4) set `Resound_MAIN_MODEL_FILE = Resound`: the app comes
up with its 1998 main window and menu.  But the 1998 main model instantiates
controller classes the port had not landed yet at the time (the inspectors,
`PreferencesManager`, `VolumeController`, `ModuleController`, …), and the
**strict GNUstep gorm loader fails the whole model on the first unknown
class** — the app would come up with *no* main window.  The 1998 Rhapsody
loader skipped unknown classes, and the 1998 code nil-guards every use of
them.

## Decision

`Source/ResoundMissingClasses.m` provides **inert stubs** for each
not-yet-ported class the main model references: they answer zero to every
send, mirroring the 1998 nil-safety so the model loads whole.  Each stub is
**deleted the moment the unit that ports the real class lands**.  With the
SndKit-leftovers unit (the twelve remaining `CLASSES` files) and the
preferences unit, all 26 of the 26 1998 application classes are real; the
file now stubs only the **five nib-internal chain names that have no source
file in the tree at all** (`ModuleControllerInstance`,
`SoundManagerInstance`, `PreferencesManagerInstance`, `Inspector`,
`ErrorHandler`) — and those stay, because the nibs reference them and no
port unit owns them.

## Consequences

- The app comes up with its full 1998 main window and menu from the first
  live-model commit, unblocked by the unit order; the CI launch check has
  shown it ever since.
- The file is a visible countdown of remaining work in every commit that
  touches it.
- `resoundnib --load`'s self-adapting expectation keeps the boundary
  explicit: the nibs whose classes are ported **must** load, the
  stubbed-class nibs may fail gracefully but must not crash.

## References

- `docs/RESOUND_SNDKIT_PLAN.md` — FU4, "Live at app startup".
- `docs/GNUSTEP_BUILD.md` — "Every 1998 app source is in the build".
