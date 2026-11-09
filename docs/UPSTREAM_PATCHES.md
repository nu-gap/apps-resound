# Upstream patches

This project carries small port patches for two pinned third-party
codebases, all kept in `patches/`:

- **leighsmith/MusicKit** (the SndKit source, vendored as the pinned
  `third_party/MusicKit` submodule): five fixes, three to build on
  modern toolchains and non-x86 architectures and to run on machines
  with half-duplex audio devices, and two for runtime correctness of
  the recording and conversion paths that the port exercises.  Applied
  by `third_party/build-sndkit.sh` so the submodule stays pristine.
- **the hermetic GNUstep stack** (pinned source commits, built into the
  CI prefix by `.github/workflows/build.yml`; there is no submodule —
  the CI fetches the trees, and the stack build step applies the
  patches to the fetch): two lifetime-semantics fixes in gnustep-gui
  that the 1998 code (which must stay byte-identical) depends on.

MusicKit patches apply from the repository root:

```sh
patch -p1 < patches/MusicKit-0001-vdsp-arch-guard.diff
patch -p1 < patches/MusicKit-0002-portmidi-timeproc-cast.diff
patch -p1 < patches/MusicKit-0003-retrievedriverlist-advance.diff
patch -p1 < patches/MusicKit-0004-streamrecorder-threshold.diff
patch -p1 < patches/MusicKit-0005-sndconvert-resample-buffer.diff
```

The GNUstep patches apply from the root of the fetched libs-gui tree
(which is exactly what the CI stack build step does; the `--dry-run`
first, so a stale patch fails the build before it half-applies):

```sh
cd libs-gui-8f804fd520c60800961e0bee072066f4bbadca94
patch -p1 --dry-run < ../GNUstep-0001-nswindow-released-when-closed-default.diff
patch -p1 --dry-run < ../GNUstep-0002-nspasteboard-retained-wrapper-map.diff
patch -p1 < ../GNUstep-0001-nswindow-released-when-closed-default.diff
patch -p1 < ../GNUstep-0002-nspasteboard-retained-wrapper-map.diff
```

(When a fix lands upstream, drop the corresponding patch and bump the
pin — for the stack, that means `GNUSTEP_STACK_REV` in
`.github/workflows/build.yml`.)

---

## 1. `SndKit/vDSP.c`: guard the x86-only SSE file (patch 0001)

**Submitted upstream:** leighsmith/MusicKit issue [#2](https://github.com/leighsmith/MusicKit/issues/2) (2026-11-03).  When it lands, drop `patches/MusicKit-0001-vdsp-arch-guard.diff` on the submodule bump.

**Suggested issue title:** *SndKit fails to build on non-x86
architectures: `vDSP.c` unconditionally includes the x86 SSE intrinsics*

**Symptom** (any non-x86 target, e.g. aarch64 Linux; the same include
`#error`s on Apple Silicon):

```
vDSP.c:13:10: fatal error: 'xmmintrin.h' file not found   (or)
/usr/lib/llvm-14/lib/clang/14.0.6/include/xmmintrin.h:14:2:
  error: "This header is only meant to be used on x86 and x64 architecture"
```

**Explanation.** `Frameworks/SndKit/vDSP.c` is a local reimplementation
of a subset of Apple's vDSP, documented in its header comment as
"emulating the behaviour of Apple's vDSP library on **Intel SSE2
architecture**".  It `#include <xmmintrin.h>` unconditionally (line 13)
and is listed in `SndKit_C_FILES`, so every SndKit build compiles it —
on every architecture.  On anything but x86/x86_64 the include aborts
the whole framework build.

The `vDSP_*` functions it provides are only referenced from
`SndAudioBuffer.m`, and only under `#if defined(__APPLE_CC__) ||
(__i386__ && __GNUC__)` — i.e. on non-x86 targets the file contributes
nothing.  Wrapping it in an x86 architecture guard is therefore the
minimal safe change: it compiles to an empty translation unit on
aarch64 (and friends) and is byte-for-byte unchanged on x86.

**Proposed fix:**

```diff
diff --git a/MusicKit/Frameworks/SndKit/vDSP.c b/MusicKit/Frameworks/SndKit/vDSP.c
index b7bcbbb..779dfdf 100644
--- a/MusicKit/Frameworks/SndKit/vDSP.c
+++ b/MusicKit/Frameworks/SndKit/vDSP.c
@@ -9,6 +9,7 @@
 
   Copyright (c) 2010 The MusicKit Project. All Rights Reserved.
 */
+#if defined(__i386__) || defined(__x86_64__)
 #include "vDSP.h"
 #include <xmmintrin.h>
 
@@ -226,3 +227,4 @@ void vDSP_dotpr(const float input1[],
 #ifdef __cplusplus
 }
 #endif
+#endif /* defined(__i386__) || defined(__x86_64__) */
```

(Alternative: guard only the intrinsics `#include` and the
`USE_INTRINSICS` branches, keeping the GCC vector-type scalar code,
which would also work on ARM.  The full-file guard is simpler and
matches the consumers' existing `__i386__` condition.)

---

## 2. `MKPerformSndMIDI_portaudio/PerformMIDI.m`: incompatible function pointer type (patch 0002)

**Submitted upstream:** leighsmith/MusicKit issue [#3](https://github.com/leighsmith/MusicKit/issues/3) (2026-11-03).  When it lands, drop `patches/MusicKit-0002-portmidi-timeproc-cast.diff` on the submodule bump.

**Suggested issue title:** *`MKPerformSndMIDI_portaudio` fails with
Clang 16+: `TIME_PROC` is an incompatible function pointer type
(error since Clang 16)*

**Symptom** (Clang >= 16 — including Apple Clang on current macOS —
in C/ObjC):

```
PerformMIDI.m:246:9: error: incompatible function pointer types
  passing 'long (*)(void *)' to parameter of type
  'PmTimeProcPtr' (aka 'int (*)(void *)')
  [-Wincompatible-function-pointer-types]
```

(two occurrences: `Pm_OpenInput`, line 246, and `Pm_OpenOutput`,
line 257; Clang < 16 reports the same code as a warning)

**Explanation.** `Pt_Time` (porttime) returns `PtTimestamp`
(`int32_t`) and takes no argument; PortMIDI's callback type is
`typedef int32_t (*PmTimeProcPtr)(void *time_info)`.  The macro
casts through an intermediate `long (*)(void *)`, which does not
match.  Clang 16 promoted
`-Wincompatible-function-pointer-types` from a warning to an error
in C and Objective-C, so any recent Clang build of the portaudio
backend (and hence of SndKit, which links it) fails.

**Proposed fix** — cast directly to the declared callback type (the
exact type of the parameters at both call sites).  The behaviour is
unchanged: the callback is invoked as declared and its argument is
ignored by `Pt_Time`, exactly as it already was; only the
intermediate, mismatched type is removed.

```diff
diff --git a/MusicKit/Frameworks/PlatformDependent/MKPerformSndMIDI_portaudio/PerformMIDI.m b/MusicKit/Frameworks/PlatformDependent/MKPerformSndMIDI_portaudio/PerformMIDI.m
index ad36c0dd..b47aee02 100644
--- a/MusicKit/Frameworks/PlatformDependent/MKPerformSndMIDI_portaudio/PerformMIDI.m
+++ b/MusicKit/Frameworks/PlatformDependent/MKPerformSndMIDI_portaudio/PerformMIDI.m
@@ -45,7 +45,7 @@ static PortMidiStream *inputStream;
 static PortMidiStream *outputStream;
 static long outputLatency = 10;
 
-#define TIME_PROC ((long (*)(void *)) Pt_Time)
+#define TIME_PROC ((PmTimeProcPtr) Pt_Time)
 #define TIME_INFO NULL
```

---

## 3. `MKPerformSndMIDI_portaudio/PerformSound.m`: infinite loop in `retrieveDriverList` with half-duplex devices (patch 0003)

**Submitted upstream:** leighsmith/MusicKit issue [#4](https://github.com/leighsmith/MusicKit/issues/4) (2026-11-06).  When it lands, drop `patches/MusicKit-0003-retrievedriverlist-advance.diff` on the submodule bump.

**Suggested issue title:** *`SNDInit` hangs forever (100% CPU) when PortAudio enumerates a playback-only or capture-only device*

**Symptom** (any machine whose PortAudio device list contains a device with
zero channels on the side being queried — e.g. the Raspberry Pi 500, whose
two HDMI `vc4-hdmi` cards are playback-only): the first SndKit audio
initialisation (`SNDInit` → `retrieveDriverList(FALSE)` for the input list)
never returns; one thread spins at 100% CPU forever. During
`Pa_Initialize` the log first shows the usual harmless
`jack server is not running or cannot be started` messages, then goes
silent. Any code path that triggers a native-format query
(`+[Snd nativeFormat]`, `convertToNativeFormat`, …) hangs with it.

**Explanation.** `retrieveDriverList` reuses one variable, `driverIndex`,
for two roles: the loop counter over the device table *and* the write
position in the returned `driverList` array. The `driverIndex++` sits
inside the `if` that tests whether a device matches (output channels for
the output list, input channels for the input list), so a non-matching
device — e.g. a playback-only HDMI card in the *input* list — is tested
forever: the compiled loop jumps back to the condition without advancing.
On machines where every enumerated device is full-duplex (typical laptops
with mic + speaker, where the ALSA hw device and the Pulse/PipeWire
"pulse"/"default" devices all have both) the two roles happen to agree
and the bug is invisible, which is why the 2001-vintage code shipped.

The sibling MIDI code in the same backend (`PerformMIDI.m`,
`SNDGetAvailableDriverNames`) already uses the correct two-variable
pattern (`deviceIndex` for the loop, `availableDriverIndex` for the
array); the sound side simply never got the same treatment.

**Proposed fix** — split the two roles: loop with a `deviceIndex` that
always advances, write matches into `driverList[driverIndex]` as before.
The returned array is byte-for-byte identical to before on any machine
where the old code worked (the match set is unchanged); the only
behavioural change is that the loop now terminates on machines with
half-duplex devices.

```diff
diff --git a/MusicKit/Frameworks/PlatformDependent/MKPerformSndMIDI_portaudio/PerformSound.m b/MusicKit/Frameworks/PlatformDependent/MKPerformSndMIDI_portaudio/PerformSound.m
index 63e0e804..bcaa9ee7 100644
--- a/MusicKit/Frameworks/PlatformDependent/MKPerformSndMIDI_portaudio/PerformSound.m
+++ b/MusicKit/Frameworks/PlatformDependent/MKPerformSndMIDI_portaudio/PerformSound.m
@@ -70,6 +70,7 @@ static float *lastRecvdInputBuffer = NULL;
 static const char **retrieveDriverList(BOOL forOutputDevices)
 {
     int driverIndex = 0;
+    int deviceIndex = 0;
     numOfDevices = Pa_GetDeviceCount();
     char **driverList;
 
@@ -83,8 +84,9 @@ static const char **retrieveDriverList(BOOL forOutputDevices)
           return NULL;
     }
     driverIndex = 0;
-    while (driverIndex < numOfDevices) {
-	const PaDeviceInfo *deviceInfo = Pa_GetDeviceInfo(driverIndex);
+    deviceIndex = 0;
+    while (deviceIndex < numOfDevices) {
+	const PaDeviceInfo *deviceInfo = Pa_GetDeviceInfo(deviceIndex);
         const char *name = deviceInfo->name;
         char *deviceName;
 
@@ -104,6 +106,7 @@ static const char **retrieveDriverList(BOOL forOutputDevices)
 	    driverList[driverIndex] = deviceName;
 	    driverIndex++;
 	}
+        deviceIndex++;
     }
     driverList[driverIndex] = NULL;
     return (const char **) driverList;
```

---

## 4. `SndKit/SndStreamRecorder.{h,m}`: expose the recorder's trigger threshold (patch 0004)

**Submitted upstream:** leighsmith/MusicKit issue [#5](https://github.com/leighsmith/MusicKit/issues/5) (2026-11-06).  When it lands, drop `patches/MusicKit-0004-streamrecorder-threshold.diff` on the submodule bump.

**Suggested issue title:** *`SndStreamRecorder` offers no way to set the
recording start-trigger threshold; a non-positive threshold (record from
the first buffer) is unreachable*

**Explanation.** `SndStreamRecorder` is a thin facade over the internal
`SndAudioProcessorRecorder`, and the one knob a caller needs is not
re-exported: `setStartTriggerThreshold:` exists only on the internal
processor.  The default is `0.002f` — the recorder waits for a sample
above that amplitude before it starts saving buffers.  A caller that
wants the classic "record whatever comes in for the duration" behaviour
(what the legacy NeXT SoundKit `Sound record:` did, and what Resound
needs on a silent or quiet input) cannot express it: there is no way to
reach the internal processor through the facade.

**Proposed fix** — re-export the existing setter as a pass-through on
the facade (matching the way the facade already forwards
`startRecording`/`stopRecording`/`delegate`):

```diff
diff --git a/MusicKit/Frameworks/SndKit/SndStreamRecorder.h b/MusicKit/Frameworks/SndKit/SndStreamRecorder.h
index 1835b010..cfa26090 100644
--- a/MusicKit/Frameworks/SndKit/SndStreamRecorder.h
+++ b/MusicKit/Frameworks/SndKit/SndStreamRecorder.h
@@ -78,6 +78,15 @@
 */
 - (BOOL) startRecording;
 
+/*! 
+  @brief   Sets the amplitude threshold the recorder waits for before it
+           starts saving buffers.  Passed through to the internal recording
+           processor; a non-positive threshold records from the first
+           buffer unconditionally.
+  @param      amplitudeThreshold
+*/
+- (void) setStartTriggerThreshold: (float) amplitudeThreshold;
+
 /*! 
   @brief   Starts the record-to-disk routines.
   @param      filename
diff --git a/MusicKit/Frameworks/SndKit/SndStreamRecorder.m b/MusicKit/Frameworks/SndKit/SndStreamRecorder.m
index 10ee8fe0..c5d75b66 100644
--- a/MusicKit/Frameworks/SndKit/SndStreamRecorder.m
+++ b/MusicKit/Frameworks/SndKit/SndStreamRecorder.m
@@ -66,6 +66,19 @@
     return [recorder startRecording];
 }
 
+////////////////////////////////////////////////////////////////////////////////
+// setStartTriggerThreshold:
+//
+// Pass-through to the internal recording processor: the amplitude a sample
+// must exceed before the recorder starts saving buffers.  A non-positive
+// threshold records from the first buffer unconditionally.
+////////////////////////////////////////////////////////////////////////////////
+
+- (void) setStartTriggerThreshold: (float) amplitudeThreshold
+{
+    [recorder setStartTriggerThreshold: amplitudeThreshold];
+}
+
 ////////////////////////////////////////////////////////////////////////////////
 // stopRecordingAndDisconnectFromStream:
 ////////////////////////////////////////////////////////////////////////////////
```

---

## 5. `SndKit/SndConvert.m`: temp buffer overflow in cross-rate `convertToSampleFormat:` (patch 0005)

**Submitted upstream:** leighsmith/MusicKit issue [#6](https://github.com/leighsmith/MusicKit/issues/6) (2026-11-06).  When it lands, drop `patches/MusicKit-0005-sndconvert-resample-buffer.diff` on the submodule bump.

**Suggested issue title:** *`free(): invalid pointer` abort in
`SndChangeSampleRate`/`resample`: the cross-rate conversion's temporary
buffer is sized a few bytes too small*

**Symptom.** A sample-rate conversion
(`-[Snd convertToSampleFormat:samplingRate:channelCount:]` on a
non-empty sound) aborts the process with `free(): invalid pointer`
(SIGABRT) in `free()` from inside `resample()` (SndResample.m) —
deterministically for some input lengths and clean for others (on the
Raspberry Pi: an 8.0 s 2-ch/44.1 kHz float capture converted to
8 kHz mono aborts 3/3; 6 s of the same capture converts fine).  The
abort reproduces for any cross-rate conversion of a sound whose
in-memory data is float32 — SndKit's in-memory format for both
file-loaded and freshly recorded sounds — and the crash only became
visible once recording produced such sounds (Resound Phase 2 unit 1b).

**Explanation.** In the six-argument
`-[SndAudioBuffer(SampleConversion) convertToSampleFormat:channelCount:
samplingRate:useLargeFilter:interpolateFilter:useLinearInterpolation:]`,
the temporary output buffer is sized from the input:

```objc
long numOfSamples = sampleFrames * format.channelCount;
NSMutableData *toData = [NSMutableData dataWithLength:
    numOfSamples * stretchFactor * SndSampleWidth(SND_FORMAT_LINEAR_16)];
```

but the consumer, `SndChangeSampleRate()`, requests
`(int)(stretchFactor * fromSound.frameCount) + 1` output frames and
`resample()` writes up to exactly that many — one *more* frame than the
buffer expression rounds to (and the `dataWithLength:` truncation
shaves the fractional samples off the allocation as well).  The write
therefore overruns `toData` by a few bytes; the run-away bytes land in
the header of the malloc chunk that `resample()` allocates directly
after it (its own `X1S`/`Y1S` filter buffers, malloc'd immediately after
`toData`), and the subsequent `free()` of that chunk aborts the
process.  Whether a given conversion trips it depends on how the
double multiply rounds for its particular frame count, which is why the
crash looked duration-dependent.  Same-rate conversions are unaffected:
they take the `memmove` branch of `SndChangeSampleRate` and never
allocate this buffer, which is why same-rate-only file round-trip tests
never caught it.

Note the 16-bit width in the expression is *correct* — `resample()`
always reads the source in its native format and writes 16-bit linear
out, so the buffer must be sized in 16-bit samples; only the frame
count term was wrong.

**Proposed fix** — size the buffer from the same expression
`SndChangeSampleRate()` uses to request output frames:

```diff
diff --git a/MusicKit/Frameworks/SndKit/SndConvert.m b/MusicKit/Frameworks/SndKit/SndConvert.m
index d9d44c06..25f75226 100644
--- a/MusicKit/Frameworks/SndKit/SndConvert.m
+++ b/MusicKit/Frameworks/SndKit/SndConvert.m
@@ -684,8 +684,16 @@ int SndChangeSampleType(void *fromPtr, void *toPtr, SndSampleFormat fromDataForm
     if (format.sampleRate != toSampleRate) {
 	double stretchFactor = toSampleRate / format.sampleRate;
 	long sampleFrames = [self lengthInSampleFrames];
-	long numOfSamples = sampleFrames * format.channelCount;
-	NSMutableData *toData = [NSMutableData dataWithLength: numOfSamples * stretchFactor * SndSampleWidth(SND_FORMAT_LINEAR_16)];
+	/* SndChangeSampleRate() below requests (floor(stretchFactor * sampleFrames) + 1)
+	 * output frames and resample() writes up to that many, so the temporary
+	 * buffer must be sized for that worst case.  The original expression
+	 * (sampleFrames * channelCount * stretchFactor * 16-bit width) truncates
+	 * below the write for some input durations; the few-byte overflow then
+	 * lands in the header of the malloc chunk directly after it (the
+	 * resample()'s own X1S/Y1S buffers) and the subsequent free() aborts
+	 * with "free(): invalid pointer".  See docs/UPSTREAM_PATCHES.md. */
+	long toNumOfSamples = ((long)(sampleFrames * stretchFactor) + 1) * format.channelCount;
+	NSMutableData *toData = [NSMutableData dataWithLength: toNumOfSamples * SndSampleWidth(SND_FORMAT_LINEAR_16)];
 	void *fromDataPtr = [data mutableBytes];
 	void *toDataPtr = [toData mutableBytes];
```

The same `+ 1` pattern exists in the streaming path
(`convertBytes:intoFrameRange:fromFormat:channelCount:samplingRate:`,
used when a sound plays through a buffer at a different rate); Resound
never reaches it (playback is same-rate) and it writes into the sound's
own buffer rather than a malloc'd temp, so it is left alone here.

---

## Verified

The build-fix patches (0001, 0002) were developed against the pinned
snapshot and verified two ways before landing here:

- full build of `MKPerformSndMIDI` + `SndKit` against a
  clang/libobjc2 GNUstep stack on aarch64 (where patch 0001 bites)
  and a headless SndKit file-I/O round trip (`.wav` -> `.au`);
- type-check of every built framework source under the x86_64
  profile of the modern-Clang GNUstep stack (where patch 0002 bites)
  with the promoted diagnostics forced to errors.

Patch 0003 was developed against the same snapshot by instrumenting the
hang on the Raspberry Pi 500 (gdb backtraces of the spinning thread,
disassembly of `retrieveDriverList` in the built framework, a `strace`
of the initialisation sequence, and a PortAudio-only control binary that
proves the platform stack itself is healthy). After the fix the same
machine initialises the audio engine, enumerates its three devices
(HDMI card, Pulse/PipeWire `pulse` and `default`), and the end-to-end
playback path was verified: a one-second tone converted to the native
format, played through the PipeWire/Pulse device, and both delegate
messages (`willPlay:… duringPerformance:`, `didPlay:… duringPerformance:`)
observed at the Snd's delegate on the main run loop.

Patches 0004 and 0005 were developed against the same snapshot for the
Phase 2 unit 1b recording re-route (see
`docs/RESOUND_SNDKIT_PLAN.md`): 0004 was verified with a standalone
probe on the Raspberry Pi 500 running the full
`SndStreamRecorder` flow (start-to-file, threshold, user stop,
read-back, conversion) with a silent virtual input, and 0005 with an
8-second capture converted 44.1 kHz -> 8 kHz, which aborted 3/3 before
the fix and completed 3/3 (plus a 1/2/4/6/10/15 s duration matrix)
after it, with the file-I/O contract tests (`resoundio`, `sndsmoke`)
unchanged. **In-app verification (2026-11-07, Phase 2 unit 1c, the
console unit):** the console's `recordDown:`/`stopDown:` path runs the
same flow inside the app (the 1998 six-argument `record:::::` call →
`SndStreamRecorder` capture of the silent virtual input on the dev
machine → user stop at ~2 s → `_finishRecording` read-back and
conversion; the capture is 44.1 kHz so the convert is same-rate
float32→linear-16 — the cross-rate path 0005 guards was verified by
the probe). This is the first in-app exercise of the 0004 threshold
(unit 1b's verification was a standalone probe on the Pi) and of the
whole `_finishRecording` sequence.

0001 and 0002 were submitted upstream on 2026-11-03 as issue
[#2](https://github.com/leighsmith/MusicKit/issues/2) (vDSP arch guard) and
issue [#3](https://github.com/leighsmith/MusicKit/issues/3) (TIME_PROC cast);
0003 followed on 2026-11-06 as issue
[#4](https://github.com/leighsmith/MusicKit/issues/4) (the
retrieveDriverList hang); 0004 and 0005 followed the same day as issue
[#5](https://github.com/leighsmith/MusicKit/issues/5) (the recorder
threshold) and issue
[#6](https://github.com/leighsmith/MusicKit/issues/6) (the resample
temp-buffer overflow).  The Resound project (nu-gap/apps-resound, branch
`gnustep-port`) vendors MusicKit as a pinned submodule and carries the
fixes in the meantime as `patches/MusicKit-0001-…` through
`MusicKit-0005-…`; each is dropped on the submodule bump once its issue
lands.

---

# Upstream patches for the GNUstep stack (gnustep-gui)

The CI builds a hermetic GNUstep stack from pinned source commits into
its own prefix (`.github/workflows/build.yml`: libobjc2 `c9f4002a`,
gnustep-make `4e31a03…`, gnustep-base `5bda5222`, gnustep-gui
`8f804fd5…`, gnustep-back `bbcc3de7…`).  Two lifetime-semantics fixes
in **gnustep-gui** are required for the 1998 code to run safely.  The
1998 sources must stay byte-identical (except forced platform
mappings), so anything a 1998 ownership pattern needs has to come from
the framework — hence patches, applied by the stack build step, with
`GNUSTEP_STACK_REV` bumped to `"2"`.

Both patches were developed against the pinned gnustep-gui on the
aarch64 dev machine with a throwaway probe (`MiscSoundView` /
`MiscSoundViewRuler` / `ResoundMiscSoundView` in a real window,
exactly the app's view chain, plus the 1998 pasteboard cut/copy flow)
and verified on the hermetic stack (see *Verification* below).  They
are **not submitted upstream yet**; each carries a suggested issue
title to use when that happens.

## G1. `NSWindow`: `isReleasedWhenClosed` defaults to NO (patch `GNUstep-0001-nswindow-released-when-closed-default.diff`)

**Suggested issue title:** *NSWindow's released-when-closed default
makes `close` a reference consumer: `[w close]` + `[w release]`
double-frees*

**Symptom.** Any code that closes a window it allocated and then
releases it (the natural 1998 teardown; e.g. Resound's
`[loadPanel close]` on the nib-outlet panel in `ModuleController.m`)
leaves the window freed: the next dispatch to it (often the explicit
`[w release]` a few lines later, or an event reaching it first) reads
the freed object header through the message dispatch and dies in
`objc_msg_lookup_sender` (wild isa → wild dtable) with a SIGSEGV.  The
probe hit this in 8/10 natural runs and 5/5 under gdb; the freed chunk
is usually reused by the time the second dispatch lands, which is why
the crash site varies (dispatch of `close` vs dispatch of `release`)
and the corrupting data (here SndKit sample data) looks random.

**Explanation.** `-[NSWindow close]` (NSWindow.m:3226) implements the
OpenStep "release when closed" contract:

```objc
if (!_f.is_released_when_closed)
  { RETAIN(self); }
...
RELEASE(self);           /* unconditional */
```

i.e. it *consumes one reference* — and `_initDefaults` (NSWindow.m:6155)
sets `_f.is_released_when_closed = YES`, so for the default window the
`RELEASE` has no balancing `RETAIN`: a window whose only reference is
the caller's is deallocated *inside* `close`, and the caller's later
`[w release]` is a use-after-free.  This is faithful to OpenStep, but
it is the one 1998 semantic that the 1998 authors themselves fought:
`FileController.m:449` carries the comment

```
// By default windows are sent a *release* message when they are closed.
// This was rather poor thinking on NeXT's part IMHO, because it violates
// the retain/release guarantee ... I'd rather have the guarantee in force,
// so after autoreleasing the window, I tell it not to do its stupid
// default behavior:
[theWindow setReleasedWhenClosed:NO];
```

and sets exactly that for the main window — but the panel path
(`ModuleController.m:171 [loadPanel close]`, a nib outlet) never got the
treatment, and the 1998 file may not be changed.  GNUstep's own
`NSMiniWindow` `_initDefaults` (NSWindow.m:459-461) already opts out of
the default with `setReleasedWhenClosed: NO`; Cocoa's
`releasedWhenClosed` default is likewise NO.  The patch changes the
default in `_initDefaults` to NO, i.e. `close` always does the
balanced RETAIN/RELEASE (net zero) and the caller's reference survives
`close` — the retain/release guarantee the 1998 code is written
against.

**Trade-off.** Code that relies on the OpenStep default — allocating a
window, taking no other reference, and expecting `close` to release it
— now leaks that window until it is explicitly released (or calls
`setReleasedWhenClosed: YES`).  Inside Resound this changes nothing:
the main window already sets NO explicitly, `NSMiniWindow` already
does, and the only pattern the patch alters is the panel path, which
becomes *correct* instead of double-freeing (the nib keeps its
reference, `close` no longer consumes it, and the nib's
`releaseConnections` balances it at the end).

**Proposed fix** (`Source/NSWindow.m`, in `_initDefaults`):

```diff
@@ -6152,7 +6152,7 @@ current key view.<br />
 //  _f.is_key = NO;
 //  _f.is_main = NO;
 //  _f.is_edited = NO;
-  _f.is_released_when_closed = YES;
+  _f.is_released_when_closed = NO;
 //  _f.is_miniaturized = NO;
 //  _f.menu_exclude = NO;
 //  _f.hides_on_deactivate = NO;
```

## G2. `NSPasteboard`: retain the wrapper in the name→pasteboard map (patch `GNUstep-0002-nspasteboard-retained-wrapper-map.diff`)

**Suggested issue title:** *NSPasteboard wrappers die with the
autorelease pool while their DO target proxy is still in use: FFI
use-after-free in `GSFFIInvocationCallback`*

**Symptom.** Pasteboard operations on a wrapper that outlives its
creating autorelease pool can die inside the DO/FFI trampoline
(`GSFFIInvocationCallback`, `obj = *(id*)args[0]` on a freed target
proxy).  The probe reproduced it under gdb on the 1998 cut/copy flow
(a second `changeCount` after `copy:`); the crash object is the
wrapper's `target` ivar — the local proxy for the pasteboard-server
object — not the wrapper the caller holds.

**Explanation.** `+[NSPasteboard initialize]` builds the name→wrapper
registry with *non-retained* values:

```objc
pasteboards = NSCreateMapTable (NSObjectMapKeyCallBacks,
  NSNonRetainedObjectMapValueCallBacks, 0);
```

while `-_pasteboardWithTarget:name:` creates new wrappers with
`[p autorelease]` and stores the server proxy in the wrapper's
`target` ivar (`ASSIGN`).  `-dealloc` then does `[target release]`.
The consequence: the wrapper's lifetime is the enclosing autorelease
pool's.  When that pool drains, the wrapper deallocates and releases
the target — even though the caller (and any in-flight DO round trip or
callback) still uses it; the next FFI dispatch on the dead proxy
crashes.  Retaining the wrapper in the registry breaks the chain: the
wrapper (and with it the target) now lives until `releaseGlobally`,
which removes the registry entry *after* telling the server to destroy
its side.  Unique pasteboards — the only ones `releaseGlobally`
applies to; general/font/ruler/find/drag are protected by the existing
illegal-release exception — are still freed completely, exactly as
before; the general pasteboard becomes one long-lived object, which
matches Cocoa's long-lived `NSPasteboard` objects.  No caller-visible
API changes.

**Proposed fix** (`Source/NSPasteboard.m`, in `+initialize`):

```diff
@@ -1106,7 +1106,7 @@ static  NSMapTable              *mimeMap = NULL;
       [self setVersion: 1];
       dictionary_lock = [[NSRecursiveLock alloc] init];
       pasteboards = NSCreateMapTable (NSObjectMapKeyCallBacks,
-	NSNonRetainedObjectMapValueCallBacks, 0);
+	NSObjectMapValueCallBacks, 0);
     }
 }
```

## Verification (GNUstep patches)

Developed and verified on the aarch64 dev machine against the pinned
gnustep-gui on the hermetic stack, with the throwaway probe of the
app's view chain + pasteboard flow (two variants: full, and one
skipping the pasteboard sections), run 15 times each before and after
the patches:

- **before**: the full-variant probe (the 1998 `close`+`release`
  teardown and an unretained pasteboard, i.e. the 1998 patterns left
  unguarded) crashed in **8/10** natural runs (all at the window
  teardown; the pasteboard FFI manifestation additionally under gdb);
  the no-pasteboard variant in **7/15** (its plain build: 2/10–7/15).
- **after** (both patches in): **0/15** for every variant, including
  the full one; the app's 10 s live run is clean.
- A control probe written with the *corrected* patterns (`setReleased
  WhenClosed: NO` + retaining the pasteboard) ran 0/40 across both
  variants (15 natural + 15 natural + 10 under gdb) before *and* after
  the patches — confirming that the two patched semantics, and nothing
  else, were the root cause.

