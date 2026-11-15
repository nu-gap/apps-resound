# 0011. Make the .gorm conversion deterministic

**Date:** 2026-11-10
**Status:** accepted

## Context

Converting the same 1998 `.nib` to `.gorm` twice produced different bytes.
Two independent sources of run-dependence: the runtime container
(`GSNibContainer`) serializes its top-level collections, which are *sets*
that a GNUstep set enumerates in pointer-hash order, so the object sequence
in the archive varied with the run's memory layout; and the converter's
loader walked the object graph in that same set order, auto-naming unnamed
objects with the *first free index* — so the run even decided **which name
strings exist** (converting `Resound.nib` twice gave `MenuItem(2)` +
`MenuItem(42)` in one run, `Menu(8)` + `MenuItem(35)` in the next).  A
version-controlled tree of generated interface files must not rewrite
itself on re-conversion.

## Decision

Fix determinism at **both ends** of the conversion pipeline:

- The runtime, `gnustep-gui` (`GNUstep-0003-gsnibcontainer-deterministic-
  serialization.diff`): archive the three top-level collections as **arrays
  in canonical name-sorted order** (the encoder builds a reversed
  object→name map; unnamed objects sort after the named ones, keeping their
  input order).  The decoder normalizes a decoded top-level array back to
  the set the in-process consumers expect, and accepts the older set
  encoding, so files written by an unpatched stack load unmodified.
- The converter, `gnustep/apps-gorm` (`Gorm-0001`, its half 2): record the
  object graph in **decode order** — the keyed unarchiver's
  `-unarchiver:didDecodeObject:` delegate fires once per object in a pure
  function of the archive bytes — and run both walks in that order, with a
  set-order fallback for anything missing.

Result: the same nib converts to **byte-identical gorms across runs**
(verified 10/10: `Console` 22146 B, `Resound` 15188 B), and a `.gorm`
re-converted to `.gorm` is byte-stable.  The full 43-gorm tree was
regenerated with the final pipeline on 2026-11-11 (two passes, trees
byte-identical, litmus test against a CI-equivalent canonical stack) and
committed.

Upstream, the determinism issue (libs-gui #1032) was **closed as not
relevant** — the `.gorm` format was never designed to be deterministic, and
a future human-readable format addresses version control from the other
side.  This is a reasonable upstream call, so per the inverted retirement
rule (ADR 0010) the patches **stay in the hermetic stack**: the port needs
a *reproducible conversion of the pinned 1998 input*, a property of the
pinned converter's process that the new format (a different, future input)
does not supply.

## Consequences

- The committed `.gorm` files are reproducible artifacts of the pinned 1998
  input; anyone re-converting 1998-era nibs with the pinned stack gets
  stable output.
- The canonical walk's only semantic difference versus the old conversion
  is three auto-named indices; the menu structure is identical.
- One known quirk is *not* determinism: the gorm→gorm round-trip keeps one
  fewer object than the nib→gorm conversion (510 vs 509 in the archive
  header) — a pre-existing difference between the two converter entry
  points.  The artifacts are defined by the nib.

## References

- `docs/UPSTREAM_PATCHES.md` — G3 (the runtime half) and the apps-gorm
  section (the converter half), cross-referenced.
