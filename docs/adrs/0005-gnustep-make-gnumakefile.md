# 0005. Build with a gnustep-make GNUmakefile; the repository root is the application directory

**Date:** 2026-11-02
**Status:** accepted

## Context

The 1998 build is Project Builder (`Source/PB.project`, `Source/Makefile`,
`./Build`), which requires Rhapsody with SoundKit — unbuildable here.
GNUstep's canonical build system is gnustep-make, and its canonical
application layout has the **repository root** as the application directory
(`Source/` + `Resources/` at the top level).  The bootstrap committed the
rules; the Rhapsody build files are kept for reference and history only.

## Decision

- A root `GNUmakefile` with gnustep-make `application.make` rules, plus
  `GNUmakefile.preamble` (project compiler/linker flags) and
  `GNUmakefile.postamble` (additional targets).
- The repository root is the app directory: the legacy
  `Resound.app/Resources` content moved to the canonical `Resources/`
  location; sources keep their `Source/` paths (objects land in
  `obj/Resound.obj/Source/`).
- `ResoundInfo.plist` is the custom Info.plist, merged at build time into
  the generated `Info-gnustep.plist`.
- The in-tree `Resound.app/` is the **build bundle** (generated,
  git-ignored) — `./Resound.app/Resound` from the tree is the local run
  loop.
- The `.desktop` file: the makefiles generate it with `pl2link`, which the
  current tools-make source releases and the Debian/Ubuntu packages do not
  ship — the postamble carries a fallback that produces it from the Info
  plist where the tool is missing (the Gershwin `/System` install uses the
  stock rule unchanged).

## Consequences

- `make -f GNUmakefile` + `./Resound.app/Resound` + `make -C test` is the
  whole local loop; adding a ported file is one list entry
  (`docs/GNUSTEP_BUILD.md` § Adding sources).
- The same makefiles build against the Gershwin `/System` reference install
  and the CI's hermetic prefix (ADR 0006) — one build system, both
  environments.
- Anything not in `Resound_RESOURCE_FILES` is not in the bundle; the
  per-platform asset split of the nib/gorm twins is decided there (ADR
  0008/0009).

## References

- `docs/GNUSTEP_BUILD.md` — the full build-system description.
