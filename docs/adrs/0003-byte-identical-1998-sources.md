# 0003. Keep the 1998 sources byte-identical except for documented mappings

**Date:** 2026-11-02
**Status:** accepted (applied from the first migrated file, 2026-11-05)

## Context

The port replaces the framework behind the 1998 code (ADR 0001), swaps the
build system (ADR 0005), and converts the interfaces (ADR 0008).  Any
"modernisation" beyond what the replacement *forces* would make it
impossible to tell a port defect from an original defect, and would destroy
the historical value of the tree that nu-gap preserves.

## Decision

The 1998 files stay byte-identical.  Every deviation must be a documented,
forced mapping — the `#import <SoundKit/SoundKit.h>` swap, the
`Sound` → `Snd` / `SoundView` → `SndView` renames, the selector renames
SndKit requires (`convertToSampleFormat:`, `lengthInSampleFrames`, …), the
`ResoundNibs` call-site swap (ADR 0009), the `SND_FORMAT_*` table the
encoding menu now builds from — each called out in the docs where it
happens.  Where a *behavioural* difference is unavoidable because SndKit's
semantics differ from SoundKit's, it is documented as a deliberate
difference, never silently absorbed into the 1998 file.  Warnings that the
1998 idioms produce under modern clang (e.g. the 1998 multi-argument
`set:`/`update:` declarations) are kept and documented as a baseline, not
"fixed" in the source.

## Consequences

- Every unit commit is a small diff auditable line-by-line against the
  1998 original; the byte-identity is the port's ground truth.
- Framework-level defects that the 1998 code depends on must be fixed
  *outside* the app: in the framework, via the port patches (ADR 0010).
- The in-repo convention calls the code "1998" (its vintage);
  **upstream-facing** texts (issue reports, patch notes) say *Resound.app*
  — the maintainer confusion this caused is recorded in
  `docs/UPSTREAM_PATCHES.md` (G3 section).
- One removal is admitted where the license decision demands it: the
  legacy `FileType.subproj` readers (ADR 0013).

## References

- `README.md` — the port section.
- `docs/GNUSTEP_BUILD.md` — the file-by-file source classification, each
  row listing its mappings.
