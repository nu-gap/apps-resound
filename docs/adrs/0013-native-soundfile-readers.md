# 0013. Read sound files with the native SndKit/libsndfile readers, not the legacy readers

**Date:** 2026-11-02 (decision); applied 2026-11-05
**Status:** accepted

## Context

The 1998 app dispatches sound-file reading through Jerome Genest's
`FileType.subproj` readers (AIFF, AU, SND, IFF, VOC, WAV, and various MPEG
formats).  The original distribution documentation states those readers may
be reused and redistributed **only for non-profit purposes** unless
permission is granted — a license knot for a repository that intends to be
redistributed.  SndKit/libsndfile reads the formats the app actually needs
natively, and sniffs content.  (User decision, 2026-11-02, Phase 0.)

## Decision

Use the **native readers of SndKit/libsndfile** for sound-file reading; do
not keep the legacy readers.  The Phase-1 file-I/O unit (2026-11-05)
executed it: the legacy `FileType.subproj` reader dispatch was **dropped**
from the app (the readers are retained in `original-archive/` and in the
upstream history, with their notices).  One deliberate divergence was
accepted: an **unreadable file returns `nil`** where Rhapsody returned an
empty sound, and the open flow guards for it.

## Consequences

- The GPL / non-profit restriction no longer touches the app build (the
  notices remain in the tree, and the README keeps the explicit warning —
  ADR 0017).
- The file-I/O contract is pinned by `resoundio`'s 44 checks: loading from
  every supported container (including uppercase extensions and a renamed
  `.voc`), the `convertOnOpen` normalisation, save + `.~snd` backup +
  info-string round trips, the writer-format guard, and the failure paths.
- This is the one *removal* the byte-identical policy (ADR 0003) admits:
  it is the documented replacement the license decision mandates, not a
  style clean-up.

## References

- `docs/RESOUND_SNDKIT_PLAN.md` — Phase 0 decision item, Phase 1 progress.
- `NU-GAP-IMPORT.md` — the original-licenses section.
