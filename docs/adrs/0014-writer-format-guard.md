# 0014. Normalize to 16-bit before writing (the writer-format guard)

**Date:** 2026-11-05
**Status:** accepted

## Context

The SndKit writer only emits `SND_FORMAT_FLOAT`, `SND_FORMAT_LINEAR_16`,
and `SND_FORMAT_LINEAR_32` data; **any other in-memory format is written as
an empty file while returning success** (verified 2026-11-05).  Loading
always yields 32-bit float (libsndfile decodes to float), so a freshly
loaded sound is writable — but a sound the user converts in-app to 8-bit
linear or µ-law (both present in the 1998 format menus) would, without a
guard, silently save a zero-byte file.  Rhapsody's writer had the same
class of problem; the 1998 code simply never hit it with in-app conversion.

## Decision

The `Snd (ResoundSound)` file-I/O category **normalises the in-memory
format to a writable one (16-bit linear) before `writeSoundfile:…`**, and
the failure paths report the guard instead of the raw write.  The contract
is pinned test-first by the `resoundio` B10–B12 checks.

## Consequences

- The port **extends** the 1998 write story — Rhapsody could write only
  `.snd`; the port writes to the containers SndKit writes (`snd`, `wav`,
  `aiff`, `au`, …) — without the silent-empty-file hazard.
- One user-visible difference: the saved file's *sample format* may differ
  from the in-memory one (documented in `docs/RESOUND_SNDKIT_PLAN.md` §2.3).
- The guard is the one place where "SndKit can do more than SoundKit" is
  turned into policy rather than accident; the info-comment persistence
  quirk (`.au` has no comment field under libsndfile 1.2) is documented
  alongside it, unfixable app-side.

## References

- `docs/RESOUND_SNDKIT_PLAN.md` — Phase 1, the `resoundio` entry.
- `README.md` — Features (the writer story).
