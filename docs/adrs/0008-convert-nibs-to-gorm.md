# 0008. Convert every NIB to .gorm; keep the 1998 folders side by side

**Date:** 2026-11-08
**Status:** accepted

## Context

The GNUstep runtime cannot read the 1998 typed-stream `.nib` — confirmed by
loading the `Console.nib` exactly the way the app does: `Failed to load
Nib`, zero windows born, every outlet nil.  Without conversion there is no
in-app UI, and the main model (the app's entire visible surface) is among
the unreadable files.  The only converter that reads the 1998 streams is
`gormtool` from `gnustep/apps-gorm`, branch `OPENSTEP_nib_support` (pinned
tip `d11b5291`) — a dev-time tool the CI never builds.

## Decision

All **44** `.nib` folders of the tree (14 under `Resources/`, 22 under
`Source/` including `FileType.subproj` and the module variants, 7 inside
the checked-in `ResoundModules/*.rmod` bundles) were run through `gormtool`
into a sibling `X.gorm` folder — `objects.gorm` (a GNUstep keyed archive)
plus `data.classes` (the class descriptions) — each re-read for round-trip
validation.  **43 of 44 convert.**  The one documented exception,
`Source/Modules/WaveBuilder/WaveBuilder.bad.nib`, is a pre-`NS`-prefix
typed stream (root class `IBObjectData` layout 24, 1996-era naming) which
the branch's reader — deliberately written for `NSIBObjectData` — does not
accept; it is a known-bad scratch copy that nothing references, and it
stays unconverted.  The **1998 `.nib` folders are kept side by side in
every location** — they are the migration source for the stepwise
re-nibbing (open each in a modern Interface Builder, save under a new
name), which the load code is prepared for (ADR 0009).  The GNUstep bundle
carries the converted `.gorm` folders only.

## Consequences

- The converted assets double the interface files in the tree, on purpose.
- The converted files are CI-gated (ADR 0007) and their generation is
  deterministic (ADR 0011); the 2026-11-11 full-tree regeneration with the
  final pipeline is the committed ground truth.
- One known cosmetic gap: the 1998 folders carry no `Resources/`
  subdirectory, so `gormtool` dropped the `NSCustomResource` image
  references (the 8 console button states, the error-window icon, …); at
  runtime the missing images fall back to the GNUstep placeholder until a
  modern re-nib re-attaches them.

## References

- `docs/RESOUND_SNDKIT_PLAN.md` — the NIB-migration work package (item 6,
  the resolution record).
- `docs/GNUSTEP_BUILD.md` — the `Resound_RESOURCE_FILES` note.
