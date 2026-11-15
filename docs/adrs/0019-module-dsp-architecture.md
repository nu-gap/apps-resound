# 0019. Module DSP architecture: real-time Audio Units, retained offline processing

**Date:** 2026-11-02 (intent recorded)
**Status:** proposed — the decision is still open; Phase 3 starts from this record

## Context

The ten 1998 modules (Channel, EchoChamber, Envelope, FFT, Filter, Gate,
Math, Mix, WaveBuilder, Zero) process sound **offline**: they transform
whole sound buffers, and WaveBuilder *generates* data.  SndKit offers
`SndAudioProcessorChain` / `SndAudioUnitProcessor` (including Apple Audio
Units) for **real-time** processing, which is the architecturally superior
path for playback-time effects.

The user's decision context (2026-11-02, Phase 0): it would be *desirable*
to run the modules on Audio Units, and *undesirable* to lose the existing
offline module processing completely.  The feasibility assessment: porting
to Audio Units is feasible for real-time effects (EchoChamber →
`AUReverb`/`AUReverb2`, Filter, Gate, Math, Mix, Envelope, Channel), but it
is **not a clean 1:1 port for all modules** — in particular FFT
(arbitrary-selection spectrum computation) and the offline design (modules
transform whole buffers; WaveBuilder generates data) do not map naturally
onto streaming real-time Audio Units.

## Decision

**Proposed, not yet made.**  The recommended hybrid, recorded here so Phase
3 starts from the documented intent: use **Audio Units (via SndKit's
processor chain) for real-time effects**, while **retaining buffer-based
offline processing** for FFT / generation / offline transformations — or
implementing custom `AUBase` subclasses where needed.  The user must
confirm the split before `Source/Modules/**` is ported.

## Consequences (if accepted)

- The module port splits into a real-time half and an offline half; the
  offline half reuses the existing 1998 DSP loops (mu-law / byte-swap /
  FFT helpers mapped to SndKit's C functions — `SndMuLawToLinear`,
  `SndSwapBigEndianSoundToHost`, …), keeping the 1998 processing
  verbatim where it works.
- The app's main path (playback, file I/O, console) is unaffected by the
  choice; the modules are a separate milestone.
- **Until the decision is made**, `Source/Modules/**` stays unported
  (Phase 3, deliberately deferred): the `resoundnib` gate covers the
  modules' converted gorm twins, and the app does not load a module in the
  no-modules build, so nothing blocks on the deferral.

## References

- `docs/RESOUND_SNDKIT_PLAN.md` — Phase 0 ("Decide DSP architecture", with
  the feasibility remarks) and Phase 3.
- `README.md` — the open milestone "Module API and the ten module
  implementations".
