# Resound + SndKit port — license compatibility review

This is the Phase 0 "License compatibility review" item of
`docs/RESOUND_SNDKIT_PLAN.md`, done 2026-11-28 ahead of
redistribution.  The 1998 distribution is a mix of
components with different terms.  This review quotes the
file-level headers, the 1998 distribution notes in
`README.html` (its "About the License Agreements For
Source Code" section), and the current dependency
packages.

## Components

### In the GNUstep build

| Component | Where | Terms |
|---|---|---|
| Resound 1998 source (Sean Luke) | `Source/` (the 26 `CLASSES` files) | per-file BSD-style: any purpose, without fee; the copyright notice in all derived source copies; author acknowledgement in distributed documentation; no use of the name in advertising |
| MiscKit-derived classes (Luke / Genest / Bourget) | `Source/Misc*` | the same BSD-style grant, "under the restrictions as noted in the MiscKit copyright notice" (see *The MiscKit notice* below) |
| the 1998 modules | `Source/Modules/*/` | as the app source; the Envelope module is Andrew Abernathy's, "given permission to reuse … freely" (the 1998 `README.html`) |
| SndKit + MKPerformSndMIDI (MusicKit) | `third_party/MusicKit` (git submodule) | permissive: "use the source code for any purpose, including commercial applications, as long as you reproduce this notice" (the Brandon / University of Glasgow core); the MusicKit additions: commercial and non-commercial, attribution and copyright messages kept intact |
| libsndfile | system package `libsndfile1-dev` (Debian 12: 1.2.0-1+deb12u1) | LGPL-2.1+ (upstream dual LGPL-2.1+ / BSD-3); dynamically linked |
| portaudio | system package `portaudio19-dev` (19.6.0-1.2) | dual LGPL-2.1+ / BSD-style; dynamically linked |
| the GNUstep base | the system / sandbox GNUstep stack | LGPL-2.1+; dynamically linked, the app is a separate work |
| the port's own code | `Source/Sound-ResoundSound.*`, `Source/ResoundNibs.*`, `Source/ResoundMissingClasses.m`, the module ports, `test/`, `docs/`, `patches/`, `GNUmakefile*` | Apache-2.0 (the root `LICENSE`, added with the nu-gap import) |

The permissive grants only require their notices to stay
in the source copies.  The port keeps every 1998
file-level header (the API migration lines are the only
changes, documented per unit), so the notices travel with
any source redistribution.  The LGPL components are
dynamically linked: the app links `-lSndKit
-lMKPerformSndMIDI`, which in turn link the system
libraries; the app stays a separate, relinkable work, so
the LGPL imposes no condition on the app sources.  No
component in the build carries a copyleft that reaches the
app sources, and none carries a non-commercial-only
restriction.

### Not in the build (kept in the tree, reference only)

- `Source/FileType.subproj/` — Jerome Genest's legacy
  file readers.  All 21 `.m` files plus the headers and
  the C decoders carry the same grant: "Permission to use,
  copy, modify, and distribute this material for any
  NON-PROFIT purpose is hereby granted.  Commercial use of
  this material is granted only with the sole permission
  of Jerome Genest."  That is a non-commercial-only
  restriction (there is no GPL in the subproject; the
  embedded Kientzle book code sits under the same
  grant).  Dropped from the app build by the Phase 0
  decision (2026-11-02, executed with the Phase 1
  category unit) — nothing in the GNUstep build
  references it.
- `Source/MiscTapper.{h,m}` — a MiscKit helper, vestigial
  (not in the 1998 `CLASSES` list, no nib reference,
  imported by nothing).  The BSD-style MiscKit grant.
- `Source/streams/` — the 1998 NXStream patch (Phase 4).
- `ResoundModules/*.rmod`, the 1998 `Resound.app`
  binaries, `original-archive/` — 1998 built outputs of
  the permissive components above; the same terms as
  their sources.
- `Source/PB.project`, `Source/Makefile`, the per-module
  `PB.project` / `Makefile*` — 1998 build system,
  reference only.

### Not present (potential dependencies)

- **lame** — SndKit's MP3 path (`SndAudioProcessorMP3Encoder.m`,
  `SndMP3.m`) is compiled only under `HAVE_LIBMP3LAME` /
  `HAVE_LIBSHOUT` / `HAVE_HIP_DECODE_INIT` /
  `HAVE_LIBMP3HIP`.  The built sandbox SndKit
  (`SndKitConfig.h`) has all four undefined, so lame,
  shout, and the HIP library are **not** in the build and
  MP3 read/write is disabled.  LAME (a BSD-style license
  with a patent clause) becomes a dependency only if MP3
  support is ever enabled; re-run this review at that
  point.

## The MiscKit notice

The vendored MiscKit-derived files state their grant is
"under the restrictions as noted in the MiscKit copyright
notice," but the 1998 distribution does not vendor that
notice (it is in neither `Source/` nor
`original-archive/`).  The 1998 `README.html` describes
the MiscKit license as one that "allows it to be reused
and redistributed without any ties whatsoever."  We treat
the in-file headers (the any-purpose grant plus the
notice and no-advertising clauses) as the operative
terms.  If the full MiscKit notice text is ever located,
add it here.

## Decisions

1. **Non-commercial redistribution of the repository:** no
   action needed.  Every component's notice stays in its
   files, and the one restrictive component (the Genest
   readers) permits non-commercial redistribution.
2. **Commercial redistribution of the repository:** remove
   `Source/FileType.subproj/` from the distribution.  The
   1998 `README.html` says exactly this for non-non-profit
   use ("you'll need to remove his subproject and tweak
   FileController.m"), and the port has already made the
   tweak — the app no longer dispatches to the readers, so
   nothing else is required.
3. **MusicKit stays a git submodule.**  Its permissive
   terms and notices travel with the pinned revision; the
   repository does not copy MusicKit source in.
4. **The root `LICENSE` (Apache-2.0) covers the port's
   own content only** (port code, build system,
   documentation, tests, patches), as the `README.md`
   Licensing section states.  The 1998 components keep
   their file-level notices.  No blanket re-licensing
   (the `NU-GAP-IMPORT.md` "Original licenses" note).

## Compatibility conclusion

Every component in the build is permissive (BSD-style /
Apache-2.0 / "any purpose") or an LGPL/BSD system library
linked dynamically.  The single non-commercial-only
component is out of the build.  **The port is therefore
freely redistributable; commercial redistribution needs
only the removal of the Genest readers.**  No GPL
copyleft appears anywhere in the chain — the plan's older
"GPL/non-profit" phrasing for the readers was
inaccurate, and the plan entries were corrected with
this review.
