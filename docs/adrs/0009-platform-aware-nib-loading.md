# 0009. Load nibs by logical name, resolving per platform

**Date:** 2026-11-08
**Status:** accepted

## Context

The 23 nib-load call sites in the tree (12 in the app, 8 in modules and the
subproject) historically passed names *with* the extension
(`@"Console.nib"`).  The GNUstep runtime reads the converted `.gorm` (ADR
0008); a native OpenStep/Cocoa build would read the kept 1998 `.nib`; and a
future re-nib of any individual nib under a new name must not ripple
through every call site.  The byte-identical policy (ADR 0003) admits at
most one forced call-site mapping here.

## Decision

Every nib-load call site goes through `Source/ResoundNibs.{h,m}`,
`+loadNibNamed:owner:` **with the logical name, no extension**.  The helper
resolves per platform: on GNUstep (the `GNUSTEP` define, which
`gnustep-config --objc-flags` supplies and a native build lacks) it passes
the bare name, which makes the `GSModelLoaderFactory` try every supported
type and find the `.gorm`; on a native build it appends `.nib` — the
original 1998 behaviour, so the kept 1998 files serve those builds.  The
makefile picks the physical asset per platform the same way: the GNUstep
bundle lists the `.gorm` folders, a native build would list the `.nib`
folders.  When a particular nib is re-saved as a modern NIB under a new
name, **only the resolution in `ResoundNibs.m` changes**.

## Consequences

- The two non-1998 lines in every migrated file that loads a nib are the
  `ResoundNibs` swap — the only interface-layer mapping the 1998 files
  carry.
- A native build remains possible in principle without re-editing a call
  site; the `GNUSTEP`-define switch is the single point of platform
  knowledge.
- The re-nibbing path is a one-line change per nib, which keeps the stepwise
  modernisation of the UI cheap.

## References

- `docs/RESOUND_SNDKIT_PLAN.md` — NIB migration, "Loading, per platform".
- `Source/ResoundNibs.{h,m}`.
