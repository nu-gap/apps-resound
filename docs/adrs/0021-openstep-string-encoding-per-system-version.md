# 0021. Decode the reader's strings per the archive's system version

**Date:** 2026-11-22
**Status:** accepted

## Context

The pinned converter's OpenStep NIB reader (`gnustep/apps-gorm`, branch
`OPENSTEP_nib_support`) decoded every typed-stream string as
`NSNEXTSTEPStringEncoding` — its comment: "These archives predate UTF-8.
Do not guess UTF-8 from byte validity."  That is correct for
NeXTSTEP/OpenStep archives and wrong for Rhapsody/Mac OS X ones, which
write strings as UTF-8: in the 1998 corpus (every file stamped with
system version 1000) the em dash `E2 80 94` came out as `U+00ED U+00A0
U+00D4` (í, nbsp, Ô — the legitimate NEXTSTEP characters of those bytes)
and rendered as mojibake in the converted gorms.  The byte-level
restoration follow-up (the commit that put the nib bytes back into the
files) did not fix the display: a `.gorm` string slot records an
*encoding tag* (a C-representation string is stored one byte per
character tagged `NSISOLatin1StringEncoding`; a wide string is UTF-16
tagged `NSUnicodeStringEncoding`), and the runtime unarchiver decodes the
slot *by the tag* — so the restored UTF-8 bytes in a tag-5 slot still
decode at runtime as â + two invisible C1 controls (menu A/B: the
committed file prints `C3 A2 C2 80 C2 99`, the genuine quote is `E2 80
99`).

## Decision

The reader (`Gorm-0002`) decodes each string per the archive's
`NXSYSTEMVERSION` — the writer toolchain's stamp in the typed-stream
header (the Objective-C runtime constant, Darwin 0.1
`objc-1.3.1/typedstream.h`: 1000 for Rhapsody and all of Mac OS X, 930 or
below for NeXTSTEP/OpenStep):

- stamp **1000 or above**: prefer UTF-8; fall back to NEXTSTEP per string
  when the bytes are not valid UTF-8 (a Rhapsody archive may still hold a
  single-byte string, e.g. `0xDD` → `U+00E9`).
- stamp **below 1000**: NEXTSTEP only.

Per-string byte validity is never the decision, in either direction: a
single NEXTSTEP byte `0xD0` is the em dash (and an invalid UTF-8 lead
byte), while a three-byte NEXTSTEP string `E2 80 94` (í nbsp Ô) is a
*valid* UTF-8 em dash — guessing by validity would corrupt 930 archives.
The reader's NSFont name bytes (the same history, a separate buffer) get
the same gating.  The re-conversion of the 1998 corpus through the fixed
reader is the standing fix; the committed gorms predate the patch and
keep the byte-restored state (a known cosmetic gap until the recommit
decision lands).

## Consequences

- The five non-ASCII strings of the corpus (em dash, apostrophe, `≤` ×2,
  `π`) decode to their true code points (wide slots) and display
  correctly — verified by the menu A/B, the panel probe, and the `Tests/`
  suite (1000-with-UTF-8, 1000-with-fallback, and 930-with-UTF-8-looking
  cases, each through the reader, the `gormtool` CLI, and a keyed
  re-import).
- Re-conversion changes 11 of the 43 tracked gorms, all inside string
  payloads (the other 32 files and every `data.classes` are
  byte-identical); file sizes move by a few bytes.
- 930 archives (the 1996 known-bad `WaveBuilder.bad.nib`) are
  byte-for-byte unaffected by the patch: their strings decode NEXTSTEP
  only, exactly as the unpatched reader did.

## References

- `docs/UPSTREAM_PATCHES.md` — the apps-gorm section, Gorm-0002.
- `docs/RESOUND_SNDKIT_PLAN.md` — the NIB section, string-encoding
  follow-up.
- ADR 0010 (the patch-carrying rule), 0011 (determinism, the same
  converter).
