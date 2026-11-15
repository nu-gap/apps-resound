# 0012. Rename the legacy main menu to `NSMenu` on conversion

**Date:** 2026-11-10
**Status:** accepted

## Context

Legacy OpenStep/Rhapsody nibs name the application's main menu `MainMenu`
(or `_NSMainMenu`).  The gorm runtime loader (`GSNibContainer
-awakeWithContext:`) wires the menu bar by looking up the **name-table key
`NSMenu`** — so a converted gorm that keeps the legacy name leaves the menu
**orphaned**: the app runs with no menu bar, and every menu key-equivalent
(File → Open, …) is dead.  The main menu is the app's most visible control
surface, and it is live at startup (ADR 0016); modern gorm documents
already name the main menu `NSMenu`, so only the legacy conversion is
affected.

## Decision

The converter patch (`Gorm-0001`, half 1) renames the legacy main menu to
`NSMenu` **after** the loader's name-preserving attach loop: the object is
already attached, and the rename updates the name-table entry the runtime
looks up.  The two functionally-changed Resound gorms (`Resources/` +
`Source/`, whose main-menu key is now `NSMenu`) were regenerated with the
final pipeline, and the full-tree regeneration of 2026-11-11 kept the
change.

## Consequences

- The app comes up with its full 1998 main menu wired — verified at launch
  in every unit since the file unit, and in the CI launch check.
- The rename is the **only functional change** the converter makes to a
  converted document; everything else it does (ADR 0011) is
  serialization-order only.
- The maintainer took the `_NSMainMenu` remapping half of the patch
  upstream ("glad you caught that"), so it will drop on the next converter
  pin bump.

## References

- `docs/UPSTREAM_PATCHES.md` — the apps-gorm section, change 1.
- `docs/RESOUND_SNDKIT_PLAN.md` — FU4 (the main model live at startup).
