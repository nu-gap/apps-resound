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
- **File writing is format-restricted (verified 2026-11-05):** the SndKit writer only emits `SND_FORMAT_FLOAT`, `SND_FORMAT_LINEAR_16` and `SND_FORMAT_LINEAR_32` data; any other in-memory format is written as an *empty file while returning success*. The ResoundSound category normalises to 16-bit first (see `test/resoundio.m` B10-B12).
- **Info comments are container-dependent (verified 2026-11-05, libsndfile 1.2):** the Snd's `NSString` info is written via the container's comment field, which libsndfile supports for aiff/wav/snd/ogg but **not for `.au`** ("File type does not support string data"). The info is kept in the Snd/view regardless; only its persistence to `.au` files is lost.
- **`SND_RATE_*` exist in SndKit** (in `MKPerformSndMIDI/SndStruct.h`, reachable via `<SndKit/SndKit.h>`): `SND_RATE_CODEC` 8012.82, `SND_RATE_LOW` 22050, `SND_RATE_HIGH` 44100, `SND_RATE_LOW_PC` 11025 — so the Rhapsody rate constants keep working unchanged (they match the values in the Rhapsody headers the app was written against).
- **Loading always yields `SND_FORMAT_FLOAT`** (libsndfile decodes to float); format is normalised on read, so a sound loaded from any container is 32-bit float until converted.
- Audio units: SndKit supports `SndAudioUnitProcessor` (Apple) — relevant for future macOS and module effects.

---

## 3. Necessary porting steps (checklist)

### Phase 0 — Prerequisites & decisions (before touching code)

- [x] **Confirm SndKit source/version** (2026-11-03): `github.com/leighsmith/MusicKit` master, **pinned as the `third_party/MusicKit` git submodule** at tip `9683c76a` (2026-02-22, an actively maintained GNUstep-fixes tip). Built in the sandbox (aarch64) and in CI against the port's GNUstep stack: the chain Resound needs is `MKPerformSndMIDI (portaudio backend) → SndKit` — `MKDSP_Native`/`MusicKit` are the unused synthesizer half. Two port fixes: `vDSP.c` arch guard (`patches/MusicKit-0001-vdsp-arch-guard.diff`, x86-only SSE file) and the `libportmidi-dev` system package (headers for the unused MIDI half). Verified end-to-end: frameworks build + install, and a headless `.wav → .au` file-I/O round trip passes (`test/sndsmoke`, fatal in CI). See `docs/GNUSTEP_BUILD.md` § SndKit.
- [ ] **DECISION (user, 2026-11-02):** Future versions of Resound shall use the **most recent git version of SndKit** (github.com/leighsmith/MusicKit master) — for the Mac OS X Server 1.2 / Rhapsody target, the GNUstep target, and the modern macOS future version.
- [ ] **License compatibility review**: MusicKit / SndKit / libsndfile / portaudio / lame terms vs Resound's existing mixed licensing (Sean Luke, MiscKit, Jerome Genest `FileType.subproj` readers — non-profit restriction). Document decisions before redistribution.
- [ ] **Decide scope of file-format handling**: rely on SndKit/libsndfile readers (`.wav`, `.aiff`, `.au`, …) vs keep Jerome Genest's legacy readers in `Source/FileType.subproj` (GPL/non-profit constraints).
- [ ] **DECISION (user, 2026-11-02):** Use the **native readers of SndKit/libsndfile** (`.wav`, `.aiff`, `.au`, …) for sound file reading; **do not** keep Jerome Genest's legacy readers in `Source/FileType.subproj`. Replace the legacy readers when the time comes (licensing: GPL/non-profit constraints).
- [ ] **Decide DSP architecture**: modules (FFT, EchoChamber, Filter, Gate, Math, Mix, WaveBuilder, Zero, Envelope, Channel) — offline buffer processing vs hooking into `SndAudioProcessorChain` / `SndAudioUnitProcessor` for real-time effects.

  **DSP architecture remarks (user decision context, 2026-11-02):** It would be desirable to run these modules on Audio Units (`SndAudioUnitProcessor` via SndKit's `SndAudioProcessorChain`, incl. Apple AudioUnits). It would be undesirable to lose the existing offline module processing completely.

  - **Feasibility of porting modules to Audio Units:** porting is *feasible* for real-time playback-time effects (e.g., EchoChamber→`AUReverb`/`AUReverb2`, Filter, Gate, Math, Mix, Envelope, Channel can map to AU processors; FFT would require a custom/third-party FFT AU or offline rendering). It is *not* a clean 1:1 port for all modules: in particular FFT (arbitrary-selection spectrum computation) and the offline-processing design (modules transform whole sound buffers; WaveBuilder generates sound data) do not map naturally onto streaming real-time Audio Units.

  - **Recommended hybrid:** use Audio Units (via SndKit's processor chain) for real-time effects, while retaining buffer-based offline processing for FFT/generation/offline transformations, or implement custom `AUBase` subclasses where needed.

### Phase 1 — Audio core: sound objects and file I/O

Progress (2026-11-05): the testable core of this phase is done,
test-first:

- [x] **`Snd (ResoundSound)` file-I/O category** — extracted from
  `FileController.{h,m}` into `Source/Sound-ResoundSound.{h,m}` and
  migrated to SndKit. Contract pinned test-first by
  `test/resoundio.m` (44 checks: load .wav/.au/.aiff/.snd/uppercase/
  renamed-.voc, the convertOnOpen normalisation, save + `.~snd` backup +
  info-string round trips, the writer-format guard, the failure paths);
  fatal in CI. The legacy `FileType.subproj` reader dispatch was dropped
  (SndKit/libsndfile reads the formats and sniffs content); the Rhapsody
  `SNDSoundStruct` info-string hack is replaced by Snd's `NSString` info;
  the category is in the app build (`Resound_OBJC_LIBS` links SndKit).
  One deliberate divergence: unreadable files return `nil` (Rhapsody
  returned an empty sound) — the Phase 2 `open:` flow must guard for it.
- [ ] Replace all `#import <SoundKit/SoundKit.h>` with SndKit framework imports in the remaining files:
  - ~~`Source/SoundManager.{h,m}`~~ — done 2026-11-06 (Phase 2, unit 1)
  - `Source/FileController.{h,m}` (class part)
  - `Source/MiscSoundView.{h,m}`, `Source/ResoundMiscSoundView.{h,m}`, `Source/ResoundMiscVolumeMeter.{h,m}`
  - `Source/ModuleSound.{h,m}`, `Source/ModuleSoundView.{h,m}`
  - `Source/ConsoleManager.{h,m}`, `Source/MiscTapper.{h,m}`, `Source/MiscVolumeMeter.{h,m}`, `Source/MiscSoundTracker.{h,m}`, `Source/VolumeController.{h,m}`
  - `Source/Modules/**` (all module implementations + controllers)
  - inspectors (`AttributesInspector`, `InfoStringInspector`, `SelectionInspector`, `ZoomInspector`, `MarksInspector`, …)

  (These are GUI-heavy and untestable headless; they belong with the
  Phase 2 playback/view chain and will be ported file by file with
  `Sound` → `Snd`, `SoundView` → `SndView` renames rather than new tests.)
- [ ] Migrate `Sound` → `Snd` types in the above: ivars, `SNDSoundStruct*` → `SndFormat`, sample-size helpers → `SndSampleWidth`/`SndFrameSize`/`SndDataSize`, `sampleCount` → `lengthInSampleFrames`, `samplingRate` (double), `dataFormat` (`SndSampleFormat`).
- [ ] Update info-string handling in the views/inspector: `Snd info` (`NSString *`) replaces the `SNDSoundStruct` info-string hack (category side done; `ResoundMiscSoundView`'s `char* info`/`loadInfo:` become `NSString`).
- [x] `FileController saveToSoundFile:` → `[snd writeSoundfile:…]` (+ error handling via `SND_ERR_*`/`SndSoundError`, which returns an `NSString` under SndKit) and `initFromForeignSoundFile:` — done in the category above.

### Phase 2 — Playback / recording / monitoring / volume

- [x] **Port `SoundManager` (done 2026-11-06, unit 1).** `Sound` → `Snd` throughout; `play`/`stop`/`pause`/`resume`/`record`/`isPlaying`/`isRecording` now use SndKit's performance-based `Snd` APIs (the plan's `Snd(Playing)` category does not exist — the methods live directly on `Snd`, alongside `SndPerformance`). The recording buffer is sized at init via `initWithFormat:channelCount:frames:samplingRate:` (SndKit has no `setDataSize:…`; the frame count is derived from the byte size the console panel passes; the old `infoSize:` has no counterpart — Snd's info is an `NSString`). The view ivar is typed `id` until the view chain is ported (its headers still import legacy SoundKit); the three app-header imports (`FileController`/`ConsoleManager`/`ModuleController`) were dropped for the same reason — all references are dynamic `id` dispatch, so the class is a self-contained SndKit-only unit. In the build since 2026-11-06.
- [x] **Port delegates to the SndKit delegate set (same unit).** `didPlay:sender` → `didPlay:sender duringPerformance:` (SndKit's performance-based signature; the view forwards its Snd's completion with the extra argument), `didRecord:sender` unchanged, **new** `hadError:sender` (the legacy app had no error path — it cleans up as in `stop:`). `willPlay:`/`willRecord:` are deliberately *not* implemented: SndKit only sends them if the delegate implements them, and the legacy app derived its state from the manager's own flags, not from these.
- [x] **Audio engine verified on the target machine (2026-11-06).** The first probe hung in `convertToNativeFormat`; diagnosis (gdb/strace/disassembly, see `UPSTREAM_PATCHES.md` §3) found an upstream MusicKit infinite loop in `retrieveDriverList` — any half-duplex device (the Pi's playback-only HDMI card) spins `SNDInit` at 100% CPU forever. Fixed by `patches/MusicKit-0003-retrievedriverlist-advance.diff`. On the Pi (Raspberry Pi 500, two HDMI outs, no speakers, no mic yet): the engine initialises, enumerates three devices (HDMI card, plus PipeWire/Pulse `pulse` and `default` with 32/32 channels), a one-second tone converts to the native format and plays, and `willPlay:…`/`didPlay:… duringPerformance:` both arrive at the Snd's delegate on the main run loop. **Environment note:** audio-capable processes outside the user's desktop session need `XDG_RUNTIME_DIR=/run/user/1000` to reach the session's PipeWire/Pulse socket (otherwise PortAudio falls into slow JACK/ALSA probing). Delegate messaging requires `NSApp` to exist (a GUI app or `[NSApplication sharedApplication]`); a bare CLI tool silently gets no delegate messages.
- [x] **Re-route the recording flow to `SndStreamRecorder` (done 2026-11-06, unit 1b).** SndKit's `Snd record:` is a stub (`NSLog("Not yet implemented!")`, `isRecording` hard-coded NO — the probe above shows it), and SndView documents "recording into the sound [NOT CURRENTLY SUPPORTED ON ANY PLATFORM]"; the working recorder is `SndStreamRecorder` (record **to a file**). `SoundManager`'s dormant `[newSound record:]` call is gone. What the unit found in the API, and what it does:
  - **SndKit gaps (verified by reading the source + probing on the Pi):** there is no `+ streamRecorder` factory (doc comment only; `+ streamClient` hard-codes the base class) — use `alloc`/`init`. The plan's `prepareForRecording:` does not exist — the real method is `prepareToRecordForDuration:`, which **ignores the duration** (a queue-size TODO), so **there is no buffer-full auto-stop**. The delegate's `didFinishRecording:` is declared but **never sent** anywhere in SndKit (only `didStartRecording:` is, from the stream thread — and probe runs on the Pi never observed even that). `stopRecording` blocks up to 30 s (0.1 s poll) until the file-writing thread flushes and closes. All of this is why completion is **app-driven**: an `NSTimer` for the mapped duration (bytes ÷ (channels × sample width × rate) = the legacy buffer-full time) and the `stop:` recording branch both funnel into `_finishRecording`.
  - `record:` allocates `[[SndStreamRecorder alloc] init]`, sets the start-trigger threshold to **-1.0** via `patches/MusicKit-0004-streamrecorder-threshold.diff` (the knob lived only on the internal `SndAudioProcessorRecorder`; the SndKit default 0.002f would wait for non-silence — the legacy SoundKit recorded whatever came in), and starts it into a temp `.wav` (`NSTemporaryDirectory` — the capture is in the native input format; 2 ch/44.1 kHz float32 on the Pi). The legacy `newSound` allocation stays as the console meter's token object (SndKit never fills it; the meter shows a zero buffer, as in unit 1).
  - `_finishRecording` (idempotent via the `recording` flag): `stopRecording` → load the temp file via `initFromSoundfile:` → `convertToSampleFormat:samplingRate:channelCount:` to the console-requested format → the legacy handoff (`consoleManager stopDown:`, `fileController newRecordedSound:`, module `soundDidRecord`) → cleanup (temp file, recorder, timer). **Deliberate behaviour change:** a user stop during recording now hands off the partial capture; the legacy `stop:` discarded it. The legacy `didRecord:` is kept as a vestigial no-path (the stub Snd never records) so the delegate surface still matches the legacy class.
  - **`patches/MusicKit-0005-sndconvert-resample-buffer.diff`** was required for the finish-time conversion: a cross-rate `convertToSampleFormat:` on a float-backed Snd overran its temp buffer by a few bytes (the allocation omitted `resample()`'s `+ 1` output frame) and aborted in `free()` — deterministically for some input durations (an 8 s 44.1 kHz → 8 kHz convert aborted 3/3; see `UPSTREAM_PATCHES.md` §5). Verified after the fix: 8 s × 3 clean plus a 1/2/4/6/10/15 s matrix, correct frame counts, `resoundio`/`sndsmoke` unchanged.
  - **In-app status at commit time:** nothing in the build reached the recording flow (the console unit was still blocked); the flow was verified at engine level (probe on the Pi — the dev machine is now covered by the console unit's probe) and by the app launch check. The Pi still has no real input device — capture verified against the silent virtual input. The `didStartRecording:`/`didProcessStreamBuffer`-never-printed mystery from the probes remains unresolved and is non-blocking (completion is timer/stop-driven).
  - **Restoration note (2026-11-07, console unit):** the `_finishRecording` implementation described above was **missing from the committed `SoundManager.m`** — declared in the header and called from `stop:` and the duration timer, but never defined, so any recording stop would have hit an unrecognised-selector crash (`resoundio` contains zero record coverage, so CI stayed green). It was re-implemented from this design when the console unit was verified, with one API correction: `initFromSoundfile:` is an *instance* method — `[[Snd alloc] initFromSoundfile:]` (SndKit's own source calls `[self init]` first and releases the allocation if the read fails). The re-implementation is now exercised in-app by the console probe.
- [ ] Port `SndView` usage in `MiscSoundView`/`ResoundMiscSoundView`/`ModuleSoundView`: `setSound:`, `soundBeingProcessed`, selection APIs, play marks (`playInFuture:beginSample:sampleCount:`), cursor/scroll APIs, `drawRect:`, pasteboard. (Note: SndView has no `record:` at all — recording stays with the SoundManager/`SndStreamRecorder` flow above. Its `hadError:` forwarding is the only delegate-error path in SndKit, so `SoundManager hadError:` activates only once the view chain exists.)
- [x] **Port the console + its meter/tracker (done 2026-11-07, unit 1c).** `ConsoleManager` on SndKit, with `MiscVolumeMeter`/`ResoundMiscVolumeMeter`/`MiscSoundTracker` (the console's meter and second tracker) in the same unit:
  - The `NXSoundIn` device ivar is replaced by an `SndFormat input_format` ivar seeded from `[Snd nativeInputFormat]` (the legacy asked the device for its channel limit / rate range / encoding list; SndKit has none of those per-device APIs). Consequences: the input-gain sliders keep their nib values and are **display-only** (no `NX_SoundDeviceInputGain*` counterpart); the input-source switch is gone (no `NX_SoundDeviceAnalogInputSource` counterpart — a comment stands in both inits); the rate menu is **always user-defined** (the native input rate seeds the field and the min/max labels; a stored non-zero rate wins — `SoundManager` resamples the capture to the requested rate in `_finishRecording`); the encoding menu is a fixed table of the three capturable SndKit formats (16-bit linear / 8-bit linear / µ-law — A-Law and AES were never usable in the 1998 file either, they carried `usable=0`).
  - The 1998 `#define __BUILDING_RHAPSODY` in the header is **kept**: the `#ifndef` blocks it guards (the app-icon `MiscVolumeLight` and the hidden window) were already dead in the 1998 Rhapsody build and stay dead (the `light` ivar is declared unconditionally — the 1998 nib's class description lists it). The dormant `MiscVolumeLight.h` import block stays as-is.
  - Two local protocols bridge the not-yet-migrated neighbours (both receivers are `id`; plain-`id` dispatch of an unknown selector would warn under this toolchain, a selector declared *anywhere visible* suppresses it): `ConsoleFileController` (`currentSound:` — `FileController` is the file unit; its header was imported transitively via `SoundDocumentTable.h` and dropped) and `ConsoleSoundViewCompat` (the 1998 SoundView play-position API the console's auto-scrolling needs — `xAxisDisplayed`/`scrollToReflectPlaying`/`getSelection:size:`/`scrollToSample:`/`setPlayMark:`/`window`; the view-chain unit implements the real ones on `SndView`). `isKindOf:` (a 1998 alias) became `isKindOfClass:`.
  - The 1998 six-argument `record: r: c: bytes: e : self` call is **byte-identical** (the preserved `record:::::` selector, see the `SoundManager` entry); the 1998 `NX_SoundStreamDataEncoding_*`→`SND_FORMAT_*` switch is gone because the encoding menu is now built from the `SND_FORMAT_*` table directly. Compiles with **zero new warnings** (the four `-Wmissing-selector-name` from the `SoundManager.h` 1998 idiom remain — documented there).
  - **Verified in-app** (headless probe): `[[ConsoleManager alloc] init]` (the in-app path; it loads the 1998 `Console.nib` — see below), the manager wired to a fresh `SoundManager`, `recordDown:` → `SndStreamRecorder` capture of the **silent virtual input on the dev machine** (unit 1b's capture verification was Pi-only) → user `stop:` at ~2 s → the restored `_finishRecording`: recorder stop, read-back, convert to the console-requested 44.1 kHz/2 ch/linear-16, flag resets, temp-file/recorder/timer cleanup — all clean, no stray file, exit 0. **Nib finding:** the 1998 `Console.nib` **does not load** under the GNUstep reader (`Failed to load Nib`; zero windows born; the manager's outlets stay nil) — the OpenStep-4.2/Gorm conversion package below is a confirmed prerequisite for the console UI in-app. The console code is nil-safe without it (every control is an outlet), and the app bootstrap loads no nib until `FileController` lands, so the unit is self-contained.
- [ ] Port the tapper and volume controls: `MiscTapper` (the 1998 tap meter; not in the original `CLASSES` list — a MiscKit helper — and absent from `Console.nib`, so no unit needs it yet) and `VolumeController` from `NXSoundOut`/`NX_SoundDevice*` to `SndStreamMixer`/`SndAudioFader` / `+[Snd isMuted]` / `+setMute:` (the volume unit).
- [ ] Port `VolumeController` accordingly.

### Phase 3 — Module API and module implementations

- [ ] Port `Sound(ModuleSound)` → `Snd(ModuleSound)`: `sampleSizePerChannel` → Snd sample-width API; `performFFTFromSoundData:…toFFTData:…`, `performIFFTFromSoundData:…fromFFTData:…`, `nextPositivePowerOfTwo:`; use `SndSwapBigEndianSoundToHost`, `SndMuLawToLinear/LinearToMuLaw`, `SndChangeSampleType`, or Resound's own `fft()` on float buffers.
- [ ] Port `SoundView(ModuleSoundView) convertToFormat:samplingRate:channelCount:` → `convertToSampleFormat:samplingRate:channelCount:` (selection-preserving conversion).
- [ ] Port all modules (`Channel`, `EchoChamber`, `Envelope`, `FFT`, `Filter`, `Gate`, `Math`, `Mix`, `WaveBuilder`, `Zero`):
  - Replace `SNDSwapSoundToHost` / `SNDSwapHostToSound` / `SNDiMulaw` / `SNDMulaw` raw-buffer loops with SndKit buffers/conversion APIs or `SndAudioProcessorChain` / `SndAudioUnitProcessor`.
  - Adapt FFT module (`drawFFT:…` uses `SNDSwapSoundToHost`, `[this_sound sampleCount]`, `[Sound performFFTFromSoundData:…]`, `needsCompacting`).

### Phase 4 — Build system and packaging

- [ ] Update `Source/PB.project`: replace `SoundKit.framework` with `SndKit.framework`; resolve `SYSTEMEXTENSIONS = (snd)` (SoundKit was a system extension in Rhapsody; SndKit is a regular framework → remove/adjust).
- [x] **DONE (2026-11-02):** Bootstrap the GNUstep build system: root `GNUmakefile` (gnustep-make `application.make` rules) + `GNUmakefile.preamble/postamble` + `ResoundInfo.plist` added; legacy `Resound.app/Resources` moved to the canonical `Resources/` app-root location; in-tree `Resound.app` bundle now the build output (git-ignored); the old tracked Rhapsody binary untracked (kept on disk, in history and `original-archive/`). Verified on the Gershwin system: builds and the app launches. See `docs/GNUSTEP_BUILD.md` — sources are added step by step (currently ready: `Resound_main.m`, `Extra.m`, `ModuleMenuNode.m`, `fft.c`; 24 files blocked on the SoundKit→SndKit migration).
- [ ] ~~Convert/adapt `Source/Makefile` …~~ **Superseded** by the root `GNUmakefile` bootstrap above; the Rhapsody `Source/Makefile` is kept for reference/history only.
- [ ] Convert the module build scripts (`Source/BuildModules`, `BuildFatModules`, per-module `PB.project`) toward GNUstep makefiles (together with the module port, Phase 3).
- [ ] Update module `PB.project` files under `Source/Modules/*/PB.project` (or convert to GNUstep makefiles).
- [ ] Handle `Source/streams/streams.h` (NXStream patch) against the SndKit stream API.
- [ ] Update `Resound.app/Resources/Info-nextstep.plist` / entitlements as needed for the new framework.
- [ ] Re-check `Resound.app` nibs: SndKit provides an `SndView` IB plugin (`SndViewIBPlugin`) — Resound's `*.nib` files reference the old `SoundView` class; may need re-nibbing or class-name adaptation.

### NIB / Interface Builder file migration — substantial remarks

Yes, the NIB migration was considered only in passing and warranted a dedicated work package. **It was carried out on 2026-11-08** (this branch); the original assessment is kept below for context, with the resolution recorded in item 6.

1. **Inventory of affected NIB files.** The distribution contains many legacy NeXT-style NIB files that must be migrated, converted, or re-authored for a SndKit/GNUstep/modern-Interface-Builder port:
   - `Resound.app/Resources/*.nib` (Console, Edit, Preferences, Volume, File, Inspector, Module, …)
   - `Source/*.nib` (Resound, AttributesInspector, Console, Edit, File, MarksInspector, Module, Preferences, SelectionInspector, …)
   - `Source/Modules/*/*.nib` (e.g. FFT).

2. **Format incompatibility.** Older NIB files use the legacy NeXT/OpenStep Interface Builder format; modern Interface Builder versions (Xcode 8 and later) use the XIB/XML format and generally cannot open the old NIBs. The GNUstep runtime likewise cannot read the 1998 typed-stream `.nib` (confirmed: the reader rejects it, zero windows born). **Verified and resolved:** the conversion path is `gormtool` from `gnustep/apps-gorm` branch `OPENSTEP_nib_support` (`gormtool --read input.nib --write output.gorm`), whose OpenStep nib reader converts the legacy typed streams into a GNUstep keyed archive the runtime `GSGormLoader` reads.

3. **Class-name divergence.** NIBs wire up legacy classes — most importantly `SoundView` and derived custom views (`MiscSoundView`, `ResoundMiscSoundView`) plus controller classes. With SndKit the equivalent class is `SndView`; nibs and any Interface Builder plugins must be migrated accordingly (SndKit ships an `SndView` IB plugin, `SndViewIBPlugin`, which the port must account for).

4. **Outlets/actions.** Custom NIBs reference IBActions/IBOutlets by selector; as controller/view code is ported to SndKit-based selectors, nib wiring must stay in sync or nibs must be recompiled.

5. **Practical migration paths.** (a) convert legacy NIBs via GNUstep tooling (using recent OpenStep 4.2 conversion capability), (b) recompile/re-target nibs, or (c) re-author nibs — with (a)/(b) preferred for a source-preserving port.

6. **Recommendation.** Treat NIB migration as a first-class work package parallel to (or preceding) deep audio-core porting, since UI-layer breakage may block end-to-end validation of the ported application.
   **Runtime confirmation (2026-11-07, console unit):** the console unit's in-app probe loaded the 1998 `Console.nib` exactly the way the app does (`[NSBundle loadNibNamed:@"Console.nib" owner:self]` inside `ConsoleManager`'s `init`) and the GNUstep reader rejected it (`Failed to load Nib`; zero windows born; the manager's outlets stay nil and the console is fully nil-safe, so the code paths still verify). Conversion is therefore a **confirmed prerequisite** for any in-app UI — the console, and (when it lands) the `FileController`-driven main nib — while nib-free units proceed unblocked (the view chain: every nib object graph contains zero SoundView objects, the views are created in code).
   **Resolution (2026-11-08): every NIB is converted, in parallel with the original.**
   - **The conversion.** All 44 `.nib` folders of the tree (14 under `Resources/`, 22 under `Source/` incl. `FileType.subproj` and the module variants, 7 inside the checked-in `ResoundModules/*.rmod` bundles) were run through `gormtool` (branch tip `d11b5291`, "Update versions for Rhapsody compatibility") into a sibling `X.gorm` folder — `objects.gorm` (a GNUstep keyed archive, "GNUstep archive" magic) plus `data.classes` (the class descriptions) — each re-read for round-trip validation. **43 of 44 convert; one documented exception:** `Source/Modules/WaveBuilder/WaveBuilder.bad.nib` is a pre-NS-prefixed typed stream (root class `IBObjectData` layout 24, the 1996-era naming) which the branch's reader — deliberately written for `NSIBObjectData` — does not accept. It is a known-bad scratch copy (nothing references it) and stays unconverted.
   - **The originals stay.** The 1998 `.nib` folders are kept side by side with the `.gorm` twins in every location; they are the migration source for the stepwise re-nibbing (open each in a modern Interface Builder, save under a new name), which the load code is prepared for (below).
   - **Loading, per platform.** All 23 nib-load call sites in the tree (12 in the app, 8 in modules/subproject) now go through `Source/ResoundNibs.{h,m}` with the **logical name, no extension** (`[ResoundNibs loadNibNamed:@"Console" owner:self]`). The helper resolves per platform: on GNUstep (the `GNUSTEP` define, which `gnustep-config --objc-flags` supplies and a native build lacks) it passes the bare name, which makes the `GSModelLoaderFactory` try every supported type and find the `.gorm`; on a native OPENSTEP/Cocoa build it appends `.nib` — the original 1998 behaviour, so the kept 1998 files serve those builds. The Makefile picks the physical asset per platform the same way: the GNUstep bundle carries the 14 `Resources/*.gorm` folders (the 1998 `.nib` folders are not listed for it), a native build would list the `.nib` folders instead. When a particular nib is re-saved as a modern NIB under a new name, only the resolution in `ResoundNibs.m` changes.
   - **Still not live at app startup.** `Resound_MAIN_MODEL_FILE` stays unset: the main nib instantiates the still-blocked `FileController` (the conversion of `Resound.nib` itself is done — the makefile comment now records that the only reason is the class). The app bootstrap loads no nib until `FileController` lands.
   - **Cosmetic gap, known:** the 1998 nib folders carry no `Resources/` subdirectory, so `gormtool` could not materialise the `NSCustomResource` image references (the 8 console button states, the error-window `Resound` icon, …) and dropped them from the archives; at runtime the missing images fall back to the GNUstep placeholder. The button-state tiffs themselves still exist in `Resources/` but are unreferenced until a modern re-nib re-attaches them.
   - **Tests.** `test/resoundnib` gates the assets: `--check` (headless, CI-fatal) verifies every `.gorm` in the tree and the built bundle — archive magic, `data.classes` plist-parse — and `--load` (display, local) loads every `.gorm` in a child process through the same `NSBundle` machinery the app uses, with a self-adapting expectation: the console, whose classes are ported, must load (it does: 5 windows), the blocked-class nibs may fail gracefully and must not crash.

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
