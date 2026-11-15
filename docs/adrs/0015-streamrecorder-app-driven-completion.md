# 0015. Record through `SndStreamRecorder`, with app-driven completion

**Date:** 2026-11-06
**Status:** accepted

## Context

SndKit's `Snd record:` is a stub (`NSLog("Not yet implemented!")`,
`isRecording` hard-coded NO — confirmed by probing), and SndView documents
recording into the sound as "NOT CURRENTLY SUPPORTED ON ANY PLATFORM".  The
working recorder is `SndStreamRecorder` (record **to a file**), and the
1998 `SoundManager`'s dormant `[newSound record:]` call had to go.  The
recorder has its own gaps (verified by reading the source and probing on
the Pi): no `+streamRecorder` factory (`+streamClient` hard-codes the base
class — use `alloc`/`init`), `prepareToRecordForDuration:` **ignores the
duration** (a queue-size TODO), the delegate's `didFinishRecording:` is
declared but **never sent** anywhere in SndKit, and `stopRecording` blocks
up to 30 s (0.1 s poll) until the file-writing thread flushes.  There is
thus no buffer-full auto-stop and no completion signal to hang the 1998
flow on.

## Decision

The recording flow is re-routed in `SoundManager`: `record:` allocates
`[[SndStreamRecorder alloc] init]`, sets the **start-trigger threshold to
-1.0** (record from the first buffer — the legacy behaviour; the SndKit
default 0.002f would wait for non-silence.  The knob lived only on the
internal `SndAudioProcessorRecorder`, so it needed a facade re-export —
`patches/MusicKit-0004`), and starts it into a temp `.wav` in
`NSTemporaryDirectory` (the capture is in the native input format).
**Completion is app-driven**: an `NSTimer` for the legacy buffer-full
duration (bytes ÷ (channels × sample width × rate)) and the `stop:`
recording branch both funnel into `_finishRecording` (idempotent via the
`recording` flag): `stopRecording` → load the temp file via
`initFromSoundfile:` → `convertToSampleFormat:samplingRate:channelCount:`
to the console-requested format → the legacy handoff (`consoleManager
stopDown:`, `fileController newRecordedSound:`, module `soundDidRecord`) →
cleanup (temp file, recorder, timer).

One **deliberate behaviour change**: a user stop during recording now
**hands off the partial capture**; the legacy `stop:` discarded it.  The
legacy `newSound` allocation stays as the console meter's token object
(SndKit never fills it), and the vestigial legacy `didRecord:` is kept as a
no-path so the delegate surface still matches the legacy class.

## Consequences

- The 1998 console UI is unchanged — its six-argument `record:::::` call is
  byte-identical (ADR 0003).
- The finish-time cross-rate conversion requires the SndKit resample
  temp-buffer fix (`patches/MusicKit-0005` — the buffer was sized a few
  bytes too small and aborted in `free()` deterministically for some
  durations).
- On machines without a real input device the flow verifies against the
  silent virtual input; the `didStartRecording:`/`didProcessStreamBuffer`
  never-printed mystery from the Pi probes remains open and non-blocking,
  because completion is timer/stop-driven, not delegate-driven.
- The `stopRecording` 30-s worst case bounds `_finishRecording`'s latency.

## References

- `docs/RESOUND_SNDKIT_PLAN.md` — Phase 2, unit 1b (the full design record).
- `docs/UPSTREAM_PATCHES.md` — patches 0004 and 0005.
