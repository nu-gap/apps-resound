# Upstream patches for leighsmith/MusicKit (SndKit)

The vendored snapshot (`third_party/MusicKit`, pinned at `9683c76a`,
master 2026-02-22) needs three small fixes to build on modern toolchains
and non-x86 architectures, and to run on machines with half-duplex audio
devices.  All are kept as patches in `patches/` (applied by
`third_party/build-sndkit.sh`) so the submodule stays pristine.  When a
fix lands upstream, drop the corresponding patch when bumping the
submodule.

All patches apply from the repository root:

```sh
patch -p1 < patches/MusicKit-0001-vdsp-arch-guard.diff
patch -p1 < patches/MusicKit-0002-portmidi-timeproc-cast.diff
patch -p1 < patches/MusicKit-0003-retrievedriverlist-advance.diff
```

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

**Submitted upstream:** not yet — candidate for a leighsmith/MusicKit issue alongside #2/#3 (this is a genuine upstream bug: unbounded CPU spin, not a build issue).

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

0001 and 0002 were submitted upstream on 2026-11-03: issue [#2](https://github.com/leighsmith/MusicKit/issues/2)
(vDSP arch guard) and issue [#3](https://github.com/leighsmith/MusicKit/issues/3)
(TIME_PROC cast); 0003 is still to be filed.  The Resound project
(nu-gap/apps-resound, branch `gnustep-port`) vendors MusicKit as a
pinned submodule and carries the fixes in the meantime as
`patches/MusicKit-0001-…` / `MusicKit-0002-…` /
`MusicKit-0003-…`; each is dropped on the submodule bump once its
issue lands.
