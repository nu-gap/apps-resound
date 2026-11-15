# 0007. Three fatal headless gates in CI

**Date:** 2026-11-08 (the set completed; the first two gates landed 2026-11-03 / 2026-11-05)
**Status:** accepted

## Context

The port must never regress silently, but the app's audio and UI paths are
not fully exercisable in CI: there is no real audio device on the runner and
the display is a headless xvfb.  The gates therefore have to be headless and
deterministic, while the heavier runtime verification (in-app probes, the
live X session) happens on the developer machines.

## Decision

Every push runs three tools from `test/`, all **fatal**:

- `sndsmoke` — exercises SndKit's libsndfile file I/O (load, write, reload)
  without any audio device or display.
- `resoundio` — the 44-check contract suite for the `Snd (ResoundSound)`
  file-I/O category, pinned test-first for Phase 1: loading from every
  supported container, the `convertOnOpen` normalisation, save + `.~snd`
  backup + info-string round trips, the writer-format guard (ADR 0014), and
  the failure paths.
- `resoundnib --check` — verifies every `.gorm` in the tree **and** the
  built bundle: archive magic + `data.classes` plist-parse (57 = 43 in-tree
  gorms + 14 bundle copies).

The boundary is deliberate: the app **launch check** (xvfb + openbox, 10 s
run; exit 124 is a pass) and the **screenshot** (ADR 0018) are
*non*-fatal — a flaky display must not mask a build result.  The display
half of the nib gate, `resoundnib --load` (loads every `.gorm` in a child
process through the same `NSBundle` machinery the app uses), runs locally
with a self-adapting expectation: the nibs whose classes are ported must
load, the blocked-class nibs may fail gracefully but must not crash.

## Consequences

- "Green CI" means the build and the contracts hold; the launch/screenshot
  logs are evidence, not proof.
- Any unit that touches a gated surface commits only with the gates green;
  the gate census (e.g. the 57 gorm count) is recorded in the unit commits
  so a drift is visible.

## References

- `docs/GNUSTEP_BUILD.md` — § SndKit (the test tools) and § Continuous
  integration.
