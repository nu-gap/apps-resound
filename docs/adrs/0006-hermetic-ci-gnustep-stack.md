# 0006. CI builds a hermetic GNUstep stack from source

**Date:** 2026-11-02
**Status:** accepted

## Context

The port and SndKit target the libobjc2 / `gnustep-2.2` **non-fragile ABI**.
The packaged GNUstep on ubuntu-24.04 (apt) is built against GCC's `libobjc`,
which lacks it — the packaged stack cannot be the CI's base.  The reference
environment (the Gershwin GNUstep install under `/System` on the dev
machine) is a source-built stack at known commits, and
`/Developer/Library/Repositories.csv` records exactly which ones.

## Decision

`.github/workflows/build.yml` installs the GNUstep **stack from source**
into a hermetic prefix (`$GITHUB_WORKSPACE/gnustep`): libobjc2 (CMake,
system install type) → gnustep-make (autoconf, `ng-gnu-gnu` library combo,
`gnustep-2.2` runtime ABI) → gnustep-base (no libdispatch) → gnustep-gui →
gnustep-back, at the exact Gershwin-reference commits.  Build order matters:
libobjc2 first, so gnustep-make's configure detects it and selects the `ng`
runtime.  The stack is built once and cached with `actions/cache` keyed on
`GNUSTEP_STACK_REV`; a stack update bumps the pinned commits **and** the
rev.  The SndKit chain is **not** cached: it is rebuilt every run (a couple
of minutes) from the pinned submodule rather than trusting a stale cached
copy, while the expensive stack stays cached.  The stack build step applies
the project's GNUstep patches (ADR 0010) with `--dry-run` first, so a stale
patch fails the build before it half-applies.

## Consequences

- The first run on a new stack rev costs ~20-30 minutes; later runs take a
  couple of minutes.
- CI (ubuntu-24.04, clang) and the Gershwin machine build the same stack —
  "verified locally" and "verified in CI" mean the same thing.
- No system GNUstep package is used at all; the hermetic prefix is
  self-contained (its `GNUstep.sh` + `GNUSTEP_CONFIG_FILE` drive every
  build in the job).

## References

- `docs/GNUSTEP_BUILD.md` — § Continuous integration, the component table.
