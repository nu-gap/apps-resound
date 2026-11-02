# Resound + SndKit — Evaluation outcome and porting checklist

**Evaluation date:** 2026-11-02
**Subject:** `/home/lars/Development/apps-resound` (Resound 3.0, Sean Luke — Rhapsody / Mac OS X Server 1.2 sound editor, imported into nu-gap)
**Candidate replacement audio framework:** [SndKit](https://github.com/leighsmith/MusicKit) (MusicKit distribution; open-source implementation of NeXT's SoundKit, originally by Stephen Brandon, ported by Leigh M. Smith)

---

## 1. Verdict

**Yes — SndKit is the way to go.**

Rationale (evidence gathered during evaluation):

1. **SndKit is the designated open-source successor of the NeXT SoundKit.** The MusicKit README states: *"The SndKit was written to be a complete open source implementation of NeXT's SoundKit."*
2. **The OO design mirrors the SoundKit design Resound was written against.** Resound is built on `Sound` + `SoundView` (state object holding an `SNDSoundStruct`, view holding a `Sound`, playback/recording status, selection/play-marks, delegates). SndKit's `Snd` + `SndView` + `SndFormat` + `SndPerformance` + `SndAudioFader` + `SndAudioProcessorChain` map onto this design almost 1:1 in spirit, i.e. the port is an *API migration* of the same architecture, not a rewrite onto an unrelated framework.
3. **Many C-level compatibility symbols were deliberately kept** in SndKit: `SndSoundError(int)`, the `SND_ERR_*` error enum, `SndSwapBigEndianSoundToHost`/`SndSwapHostToBigEndianSound`, `SndMuLawToLinear`/`SndLinearToMuLaw`, `SndChangeSampleType`, `SndChangeSampleRate`, `SndSampleWidth`, `SndFrameSize`, `SndDataSize`, `SndFormat`, `SndFormatOfSNDStreamBuffer`, `SndFormatDescription`, etc.
4. **SndKit already targets the required platform matrix** (per MusicKit supported-platforms table): OpenStep 4.2, GNUstep (Linux via portaudio), MacOS X-Server V1.0–1.2, MacOS X (CoreAudio), Windows. The MacOS X / X Server 1.2 support was done by Leigh Smith and is first-class for that era; the GNUstep support is via `MKPerformSndMIDI_portaudio`.
5. **Capabilities needed by Resound already exist in SndKit:** sound file I/O (`initFromSoundfile:`, `readSoundfile:startFrame:frameCount:`, `writeSoundfile:fileFormat:dataFormat:`, `+soundFileExtensions`, `+isPathForSoundFile:`, `+defaultFileExtension`, `soundFormatOfFilename:`), sample-format/rate/channel conversion (`convertToSampleFormat:samplingRate:channelCount:`, `SndChangeSampleType`, `SndChangeSampleRate`), mu-law, FFT-oriented DSP helpers, metering (`SndMeter`), playback/recording (`Snd`, `SndPerformance`, `SndStreamRecorder`, `SndStreamPlayer`, `SndStreamMixer`, `SndStreamInput`, `SndAudioProcessorRecorder`, `SndAudioProcessorReverb`, …), volume/balance/mute (`SndAudioFader`, `+[Snd isMuted]`, `+setMute:`).
6. **SndKit retains deprecated SoundKit-compatibility methods** (e.g. `play:beginSample:sampleCount:`, `playInFuture:beginSample:sampleCount:`, `stop:`, `pause:`, `resume:`, `record:`, `isPlayable`, …), indicating an intentional compatibility layer toward the old SoundKit API.

**Conclusion:** replacing the defunct NeXT/Rhapsody `SoundKit.framework` with `SndKit.framework` is technically feasible and is the recommended direction for a future GNUstep / MacOS X / modern macOS version of Resound.

---

## 2. Assessment of source-level compatibility (findings)

### 2.1 Mostly-compatible pieces (migration effort expected, not redesign)

| Resound (SoundKit) | SndKit (successor) | Effort |
|---|---|---|
| `SNDSoundError(err)` | `SndSoundError(int err)` | none |
| `SND_ERR_*` error codes | `SND_ERR_*` enum (`SND_ERR_NONE` …) | none |
| `SNDSwapSoundToHost` / `SNDSwapHostToSound` | `SndSwapBigEndianSoundToHost` / `SndSwapHostToBigEndianSound` | low |
| `SNDiMulaw` / `SNDMulaw` | `SndMuLawToLinear` / `SndLinearToMuLaw` | low |
| `SND_FORMAT_*` codes | `SndSampleFormat` (`SND_FORMAT_*`-style codes) | low–medium |
| `Sound` concept | `Snd` (format + buffers + performance + fader) | medium |
| `SNDSoundStruct` | `SndFormat` | medium |
| `[snd writeSoundfile:fn]` | `writeSoundfile:fileFormat:dataFormat:` / `writeSoundfile:` | low |
| `[snd initFromSoundfile:]` | unchanged (kept) | none |
| `SoundView`-era display/selection | `SndView` (design based on SoundKit Release 2.0) | medium |

### 2.2 Divergent / renamed pieces (porting required)

| Resound (SoundKit) | SndKit | Action |
|---|---|---|
| Class `Sound` | Class `Snd` | rename all references / categories (`@interface Snd(ModuleSound)`) |
| Class `SoundView` | Class `SndView` | rename; IB plugin exists (`SndViewIBPlugin`) |
| Method `convertToFormat:samplingRate:channelCount:` | `convertToSampleFormat:samplingRate:channelCount:` | rename in `ModuleSoundView` category + all modules |
| Method `sampleSizePerChannel` / raw `char*` FFT input | `SndSampleWidth` / buffer/FM conversion helpers | adapt `ModuleSound` FFT category |
| Method `play:sender` (returns void/NX) | `play` / `play:` (returns `SndPerformance *`) | adapt `SoundManager`, `SndView` |
| Method `stop:sender` / `pause:sender` / `resume:sender` / `record:sender` | `stop` / `pause` / `resume` / `record` (performances-based) | adapt |
| Sound status values (`NX_SoundPlaying`, `NX_SoundStopped`, `NX_SoundRecording`, …) | `SndPerformance` state / `Snd isPlaying` / `isRecording` | adapt `ConsoleManager`, `MiscSoundTracker`, `ResoundMiscVolumeMeter`, meters |
| Delegate methods `didPlay:sender`, `didRecord:sender` | `didPlay:duringPerformance:`, `didRecord:`, `willPlay:duringPerformance:`, `hadError:` | adapt `SoundManager` delegate |
| `[Sound getVolume:...]` / `[Sound setVolume:...]` / `[Sound getMute:]` / `[Sound setMute:]` / `[Sound isMuted]` | `SndAudioFader` (`setAmp:clearingEnvelope:`, `setBalance:clearingEnvelope:`, ramps), `+[Snd isMuted]`, `+setMute:` | adapt `MiscSoundTracker`, `VolumeController`, console |
| `Sound dataSize` / `sampleCount` / `samplingRate` / `channelCount` / `dataFormat` semantics | `Snd dataSize` (long), `lengthInSampleFrames`, `samplingRate` (double), `channelCount`, `dataFormat` (`SndSampleFormat`) | adapt semantics (frame vs sample) |
| `NXSoundIn` / `NXSoundOut` / `NX_SoundDevice*` / `NX_SoundStreamDataEncoding_*` | `SndStreamManager`, `SndStreamRecorder`, `SndStreamPlayer`, `SndStreamMixer`, `SndStreamInput`, `SndAudioProcessor*` | adapt `ConsoleManager`, `MiscTapper`, `MiscVolumeMeter`, `MiscSoundTracker`, `VolumeController` |
| Info string handling (`char*` in `SNDSoundStruct`) | `Snd info` (`NSString *`) | adapt `FileController`/`ResoundMiscSoundView` |
| `[soundview convertToFormat:...]` | `[snd convertToSampleFormat:...]` | rename + preserve selection logic |

### 2.3 Behavior differences to plan for

- Playback/recording are now performance-based (`SndPerformance`) rather than sound-status-based; stop semantics, play-marks and selection playback map to `playInFuture:beginSample:sampleCount:`-style APIs.
- Recording is format-based (`initWithFormat:channelCount:frames:samplingRate:` / `initWithAudioBuffer:`) instead of `setDataSize:...` + `record:`.
- Volume/mute moved from `Sound` methods to `SndAudioFader` / static `+[Snd …]` API.
- File writing is libsndfile-backed (`writeSoundfile:fileFormat:dataFormat:`) with modern format extensions (`.au`, `.snd`, `.wav`, `.aiff`, …) rather than Rhapsody-only `.snd`.
- Audio units: SndKit supports `SndAudioUnitProcessor` (Apple) — relevant for future macOS and module effects.

---

## 3. Necessary porting steps (checklist)

### Phase 0 — Prerequisites & decisions (before touching code)

- [ ] **Confirm SndKit source/version**: use `github.com/leighsmith/MusicKit` master; build required frameworks in order (`MKPerformSndMIDI` [portaudio or MacOSX] → `SndKit` → `MKDSP_Native` → `MusicKit`), or use binary distributions.
- [ ] **DECISION (user, 2026-11-02):** Future versions of Resound shall use the **most recent git version of SndKit** (github.com/leighsmith/MusicKit master) — for the Mac OS X Server 1.2 / Rhapsody target, the GNUstep target, and the modern macOS future version.
- [ ] **License compatibility review**: MusicKit / SndKit / libsndfile / portaudio / lame terms vs Resound's existing mixed licensing (Sean Luke, MiscKit, Jerome Genest `FileType.subproj` readers — non-profit restriction). Document decisions before redistribution.
- [ ] **Decide scope of file-format handling**: rely on SndKit/libsndfile readers (`.wav`, `.aiff`, `.au`, …) vs keep Jerome Genest's legacy readers in `Source/FileType.subproj` (GPL/non-profit constraints).
- [ ] **DECISION (user, 2026-11-02):** Use the **native readers of SndKit/libsndfile** (`.wav`, `.aiff`, `.au`, …) for sound file reading; **do not** keep Jerome Genest's legacy readers in `Source/FileType.subproj`. Replace the legacy readers when the time comes (licensing: GPL/non-profit constraints).
- [ ] **Decide DSP architecture**: modules (FFT, EchoChamber, Filter, Gate, Math, Mix, WaveBuilder, Zero, Envelope, Channel) — offline buffer processing vs hooking into `SndAudioProcessorChain` / `SndAudioUnitProcessor` for real-time effects.

  **DSP architecture remarks (user decision context, 2026-11-02):** It would be desirable to run these modules on Audio Units (`SndAudioUnitProcessor` via SndKit's `SndAudioProcessorChain`, incl. Apple AudioUnits). It would be undesirable to lose the existing offline module processing completely.

  - **Feasibility of porting modules to Audio Units:** porting is *feasible* for real-time playback-time effects (e.g., EchoChamber→`AUReverb`/`AUReverb2`, Filter, Gate, Math, Mix, Envelope, Channel can map to AU processors; FFT would require a custom/third-party FFT AU or offline rendering). It is *not* a clean 1:1 port for all modules: in particular FFT (arbitrary-selection spectrum computation) and the offline-processing design (modules transform whole sound buffers; WaveBuilder generates sound data) do not map naturally onto streaming real-time Audio Units.

  - **Recommended hybrid:** use Audio Units (via SndKit's processor chain) for real-time effects, while retaining buffer-based offline processing for FFT/generation/offline transformations, or implement custom `AUBase` subclasses where needed.

### Phase 1 — Audio core: sound objects and file I/O

- [ ] Replace all `#import <SoundKit/SoundKit.h>` with SndKit framework imports in:
  - `Source/SoundManager.{h,m}`, `Source/FileController.{h,m}`
  - `Source/MiscSoundView.{h,m}`, `Source/ResoundMiscSoundView.{h,m}`, `Source/ResoundMiscVolumeMeter.{h,m}`
  - `Source/ModuleSound.{h,m}`, `Source/ModuleSoundView.{h,m}`
  - `Source/ConsoleManager.{h,m}`, `Source/MiscTapper.{h,m}`, `Source/MiscVolumeMeter.{h,m}`, `Source/MiscSoundTracker.{h,m}`, `Source/VolumeController.{h,m}`
  - `Source/Modules/**` (all module implementations + controllers)
  - inspectors (`AttributesInspector`, `InfoStringInspector`, `SelectionInspector`, `ZoomInspector`, `MarksInspector`, …)
- [ ] Migrate `Sound` → `Snd` types: ivars, `SNDSoundStruct*` → `SndFormat`, sample-size helpers → `SndSampleWidth`/`SndFrameSize`/`SndDataSize`, `sampleCount` → `lengthInSampleFrames`, `samplingRate` (double), `dataFormat` (`SndSampleFormat`).
- [ ] Update info-string handling: `Snd info` (`NSString *`) replaces the `SNDSoundStruct` info-string hack (`ResoundMiscSoundView` comment: info strings not handled correctly by SNDSoundStructs).
- [ ] Update `FileController saveToSoundFile:` → `[snd writeSoundfile:... fileFormat:dataFormat:]` (+ error handling via `SND_ERR_*`/`SndSoundError:`); update `initFromForeignSoundFile:` paths.

### Phase 2 — Playback / recording / monitoring / volume

- [ ] Port `SoundManager` to `Snd(Playing)`: `play`, `play:`, `stop`, `stop:`, `pause`, `pause:`, `resume`, `resume`, `record`, `isPlaying`, `isRecording`, `isPlayable`, error returns.
- [ ] Port delegates to `SndDelegate`: `willPlay:duringPerformance:`, `didPlay:duringPerformance:`, `willRecord:`, `didRecord:`, `hadError:` (replaces `didPlay:sender` / `didRecord:sender`).
- [ ] Port `SndView` usage in `MiscSoundView`/`ResoundMiscSoundView`/`ModuleSoundView`: `setSound:`, `soundBeingProcessed`, selection APIs, play marks (`playInFuture:beginSample:sampleCount:`), cursor/scroll APIs, `drawRect:`, pasteboard.
- [ ] Port console/tapper/volume-meter/sound-tracker from `NXSoundIn`/`NXSoundOut`/`NX_SoundDevice*`/`NX_SoundStreamDataEncoding*`/`NX_Sound*` status to `SndStreamManager`/`SndStreamRecorder`/`SndStreamPlayer`/`SndStreamMixer`/`SndStreamInput` + `SndMeter`; port volume/mute to `SndAudioFader` / `+[Snd isMuted]` / `+setMute:`.
- [ ] Port `VolumeController` accordingly.

### Phase 3 — Module API and module implementations

- [ ] Port `Sound(ModuleSound)` → `Snd(ModuleSound)`: `sampleSizePerChannel` → Snd sample-width API; `performFFTFromSoundData:…toFFTData:…`, `performIFFTFromSoundData:…fromFFTData:…`, `nextPositivePowerOfTwo:`; use `SndSwapBigEndianSoundToHost`, `SndMuLawToLinear/LinearToMuLaw`, `SndChangeSampleType`, or Resound's own `fft()` on float buffers.
- [ ] Port `SoundView(ModuleSoundView) convertToFormat:samplingRate:channelCount:` → `convertToSampleFormat:samplingRate:channelCount:` (selection-preserving conversion).
- [ ] Port all modules (`Channel`, `EchoChamber`, `Envelope`, `FFT`, `Filter`, `Gate`, `Math`, `Mix`, `WaveBuilder`, `Zero`):
  - Replace `SNDSwapSoundToHost` / `SNDSwapHostToSound` / `SNDiMulaw` / `SNDMulaw` raw-buffer loops with SndKit buffers/conversion APIs or `SndAudioProcessorChain` / `SndAudioUnitProcessor`.
  - Adapt FFT module (`drawFFT:…` uses `SNDSwapSoundToHost`, `[this_sound sampleCount]`, `[Sound performFFTFromSoundData:…]`, `needsCompacting`).

### Phase 4 — Build system and packaging

- [ ] Update `Source/PB.project`: replace `SoundKit.framework` with `SndKit.framework`; resolve `SYSTEMEXTENSIONS = (snd)` (SoundKit was a system extension in Rhapsody; SndKit is a regular framework → remove/adjust).
- [ ] Update module `PB.project` files under `Source/Modules/*/PB.project` (or convert to GNUstep makefiles).
- [ ] Convert/adapt `Source/Makefile`, `Makefile.preamble`, `Makefile.postamble`, `Source/Build`, `Source/BuildFat`, `Source/BuildModules`, `Source/BuildFatModules`, `Source/Clean`, `Source/FinallyInstall`, `Source/OpenAllProjects` from Rhapsody Project Builder makefiles toward GNUstep `GNUmakefile` conventions.
- [ ] Handle `Source/streams/streams.h` (NXStream patch) against the SndKit stream API.
- [ ] Update `Resound.app/Resources/Info-nextstep.plist` / entitlements as needed for the new framework.
- [ ] Re-check `Resound.app` nibs: SndKit provides an `SndView` IB plugin (`SndViewIBPlugin`) — Resound's `*.nib` files reference the old `SoundView` class; may need re-nibbing or class-name adaptation.

### NIB / Interface Builder file migration — substantial remarks

Yes, the NIB migration was considered only in passing and warrants a dedicated work package:

1. **Inventory of affected NIB files.** The distribution contains many legacy NeXT-style NIB files that must be migrated, converted, or re-authored for a SndKit/GNUstep/modern-Interface-Builder port:
   - `Resound.app/Resources/*.nib` (Console, Edit, Preferences, Volume, File, Inspector, Module, …)
   - `Source/*.nib` (Resound, AttributesInspector, Console, Edit, File, MarksInspector, Module, Preferences, SelectionInspector, …)
   - `Source/Modules/*/*.nib` (e.g. FFT).

2. **Format incompatibility.** Older NIB files use the legacy NeXT/OpenStep Interface Builder format; modern Interface Builder versions (Xcode 8 and later) use the XIB/XML format and generally cannot open the old NIBs. Recent OpenStep 4.2 support reportedly allows conversion of such NIB files into GNUstep-specific formats — this is the likely conversion path for a source-preserving port, and it should be verified against the actual toolchain before relying on it.

3. **Class-name divergence.** NIBs wire up legacy classes — most importantly `SoundView` and derived custom views (`MiscSoundView`, `ResoundMiscSoundView`) plus controller classes. With SndKit the equivalent class is `SndView`; nibs and any Interface Builder plugins must be migrated accordingly (SndKit ships an `SndView` IB plugin, `SndViewIBPlugin`, which the port must account for).

4. **Outlets/actions.** Custom NIBs reference IBActions/IBOutlets by selector; as controller/view code is ported to SndKit-based selectors, nib wiring must stay in sync or nibs must be recompiled.

5. **Practical migration paths.** (a) convert legacy NIBs via GNUstep tooling (using recent OpenStep 4.2 conversion capability), (b) recompile/re-target nibs, or (c) re-author nibs — with (a)/(b) preferred for a source-preserving port.

6. **Recommendation.** Treat NIB migration as a first-class work package parallel to (or preceding) deep audio-core porting, since UI-layer breakage may block end-to-end validation of the ported application.

### Phase 5 — Validation and target platforms

- [ ] **GNUstep/Linux**: build SndKit + `MKPerformSndMIDI_portaudio` backend; build Resound against it; verify playback/recording, modules, file I/O.
- [ ] **MacOS X / MacOS X Server 1.2**: build SndKit + `MKPerformSndMIDI_MacOSX` (CoreAudio/CoreMIDI) backend; verify against the historical X Server 1.2 target.
- [ ] **Modern macOS**: assess CoreAudio API drift / Apple Silicon / GNUstep-on-Apple-Silicon status; plan migration.
- [ ] Regression tests: open/save round-trips (`.snd`/`.au`, `.wav`, `.aiff`), FFT module, EchoChamber/Filter/Gate/Math/Mix/WaveBuilder/Zero/Envelope/Channel modules, recording (CODEC mic, linear16), playback, volume/mute, metering.

### Phase 6 — Documentation

- [ ] Update repository docs (`README.md`, `NU-GAP-IMPORT.md`, `Source/README.*`) to reflect the SndKit-based port direction.

---

## 4. Risks / open questions

1. **Modern macOS compatibility** of SndKit's CoreAudio backend (codebase vintage ~2000 vs macOS 10.7–15 / Apple Silicon) — main open risk for the "modern macOS compatible future version" goal.
2. **GNUstep GUI/AppKit version compatibility** for `SndView` (NSView subclass) and the IB plugin.
3. **libsndfile / codec coverage** for the legacy file formats Resound reads (VOC, MPEG, IFF/SVX, …) vs what libsndfile provides.
4. **MP3** support (`lame`) inside SndKit — licensing/availability notes.
5. **Real-time DSP**: mapping Resound's module effects onto `SndAudioProcessorChain` / `SndAudioUnitProcessor` vs offline processing.
6. **Performance/latency**: new playback engine (buffer queue + performances) vs old SoundKit streaming — behavioral verification needed.
7. **License compatibility** for redistributing Resound together with SndKit-derived components.

---

## 5. Recommendation

Proceed with **SndKit as the replacement for the defunct NeXT SoundKit** in Resound:

- **First milestone:** minimal port — get `Snd`/`SndView` playback + file I/O + one module (e.g. FFT or EchoChamber) compiling and running under GNUstep (Linux) and MacOS X.
- **Subsequent milestones:** full migration of SoundManager, meters/tapper/trackers, volume/mute, modules, build system, validation.
- **Long-term:** maintain SndKit's CoreAudio backend for modern macOS; use portaudio backend for GNUstep/Linux.

---

## 7. Strategic decision: keep SoundKit (Rhapsody-only) vs. move fully to SndKit

**Question raised by the user (2026-11-02):** Since the current Source is supposed to build on Mac OS X Server 1.2 (Rhapsody) via SoundKit, should Resound keep its SoundKit-based implementation for Rhapsody, or should the whole codebase be moved over to SndKit?

### Option A — Keep the SoundKit-based codebase (Rhapsody-only / historical preservation)

**Pros:**
- No audio-core porting effort; original behavior preserved as-is.
- Existing Rhapsody build (`./Build`, `BuildFat`) and bundled binaries remain authoritative.
- Lowest immediate risk; fastest path to a working historical Rhapsody app.

**Cons:**
- SoundKit is defunct and no longer available → no GNUstep path, no modern macOS path, no future extension capability.
- Conflicts with the purpose of the nu-gap import (future GNUstep work).
- The user already frames SoundKit as "no longer available in any form and probably should be replaced."

### Option B — Move the whole codebase over to SndKit (full migration)

**Pros:**
- Open-source successor with ongoing maintenance (MusicKit/SndKit project).
- Portable across GNUstep (portaudio backend, Linux), MacOS X / X Server 1.2 (CoreAudio), MacOS X, Windows; modern macOS is the eventual target.
- High OO-design compatibility with the old SoundKit design; C-compatibility layer retained (`SndSoundError`, `SND_ERR_*`, `SndSwap*`, `SndMuLaw*`, `SND_FORMAT_*`, `writeSoundfile:fileFormat:dataFormat:`, `convertToSampleFormat:…`).
- Effects can hook into `SndAudioProcessorChain` / `SndAudioUnitProcessor` (incl. AudioUnits) — architecturally superior for future DSP.

**Cons:**
- Large migration effort: app sources (~30 files) + modules + build system (PB→GNUstep) + nibs (SoundView→SndView) + DSP loops + metering/recording/playback state.
- Not source-compatible → behavior changes (performance-based playback/recording, fader-based volume/mute, libsndfile file formats, NSString info strings).
- Regression risk in historically-working behavior (workarounds: info-string bug, paste bug, compaction, play marks).
- SndKit's own modern-macOS support may itself need maintenance.

### Assessment

For the stated goal — a future version that runs on **GNUstep**, **Mac OS X Server 1.2**, and **modern macOS** — **Option B (full move to SndKit) is the recommended direction**.

- Option A would freeze development at Rhapsody and forfeit the future-version goal.
- Option B subsumes Option A functionally, while the original SoundKit implementation remains preserved in `original-archive/` and upstream history.

---

*End of evaluation summary and checklist. No source files in `/home/lars/Development/apps-resound` were modified during this evaluation.*
