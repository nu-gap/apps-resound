# Resound GNUstep Build System

This document describes the gnustep-make compatible build system for the
GNUstep port of Resound (branch `gnustep-port`).

## Layout

The repository root **is** the application directory (the canonical GNUstep
app layout):

```
apps-resound/
├── GNUmakefile               # app_Resound (application.make rules)
├── GNUmakefile.preamble      # project-specific compiler/linker flags
├── GNUmakefile.postamble     # additional makefile targets (hooks)
├── ResoundInfo.plist         # custom Info.plist, merged at build time
├── Source/                   # sources (the Rhapsody-era code, being ported)
├── Resources/                # resources (nibs, tiffs, Documentation)
├── third_party/              # vendored dependencies
│   ├── MusicKit/             # git submodule (pinned), the SndKit source
│   └── build-sndkit.sh       # builds + installs the SndKit chain
├── patches/                  # port patches for the pinned submodule
├── test/                     # the five test tools (+ Tone.wav input)
├── Resound.app/              # IN-TREE BUILD BUNDLE (generated, git-ignored)
│   ├── Resound               # generated executable
│   ├── stamp.make
│   └── Resources/            # generated Info-gnustep.plist, .desktop, icons
├── obj/                      # build objects (git-ignored)
├── API/                      # public module API headers (for module developers)
├── ResoundModules/           # built .rmod module bundles (Rhapsody-era)
├── original-archive/         # original Resound 3.0 source archive (history)
└── docs/                     # project documentation
```

`Resound.app/` and `obj/` are build output and are ignored by git (see
`.gitignore`). Everything under `Source/` and `Resources/` is source.

## Environment

The build assumes the Gershwin GNUstep system domain in `/System`
(makefiles in `/System/Library/Makefiles`, headers in
`/System/Library/Headers`, libraries in `/System/Library/Libraries`).
Set up the environment with:

```sh
. /System/Library/Makefiles/GNUstep.sh
```

(or the Gershwin login environment). The compiler is `clang` with the
`gnustep-2.2` Objective-C runtime (see `/System/Library/Makefiles/config.make`).

## Building

```sh
make -f GNUmakefile            # build (in-tree: Resound.app/ + obj/)
make -f GNUmakefile install    # install into the SYSTEM domain (/System/Applications, needs root)
make -f GNUmakefile distclean  # remove all build artifacts
```

To install into the user domain instead of the system domain:

```sh
make -f GNUmakefile install GNUSTEP_INSTALLATION_DOMAIN=USER
```

Run the built app from the tree:

```sh
./Resound.app/Resound          # needs a display
```

## SndKit (MusicKit)

The audio framework. Resound's original code is written against the
defunct NeXT/Rhapsody `SoundKit.framework`; the port replaces it with
[SndKit](https://github.com/leighsmith/MusicKit) (the open-source
successor, part of the MusicKit distribution). See
`docs/RESOUND_SNDKIT_PLAN.md` for the migration plan and API mapping.

The source is vendored as the `third_party/MusicKit` git submodule,
**pinned to the commit recorded in the index** (currently the
`leighsmith/MusicKit` master tip `9683c76a`, 2026-02-22). To update
SndKit, bump the submodule (`git -C third_party/MusicKit fetch && git -C
third_party/MusicKit checkout <commit> && git add third_party/MusicKit`);
the port patches in `patches/` must then be re-checked against the new
tip (the build script refuses to continue if a patch no longer applies).
After a build, the submodule's working tree shows the applied patch (and
build artifacts) - expected; restore the pristine state with
`git -C third_party/MusicKit checkout -- . && git -C third_party/MusicKit
clean -fdx`.

Resound needs only two of the four MusicKit frameworks:

| framework | role |
|---|---|
| `MKPerformSndMIDI` (portaudio backend) | the performance engine SndKit plays through (MIDI half unused by Resound) |
| `SndKit` | `Snd`, `SndView`, `SndFormat`, file I/O, processors, … |

(`MKDSP`/`MusicKit` are the synthesizer half and are not built.)

Build and install into the active GNUstep prefix:

```sh
. <prefix>/share/GNUstep/Makefiles/GNUstep.sh
export GNUSTEP_CONFIG_FILE=<prefix>/etc/GNUstep/GNUstep.conf
git submodule update --init          # once, after a fresh clone
third_party/build-sndkit.sh          # idempotent; rebuilds incrementally
```

This installs `SndKit.framework` and `MKPerformSndMIDI.framework` into
`<prefix>/lib/GNUstep/Frameworks/` **and** the flat `libSndKit.so` /
`libMKPerformSndMIDI.so` into `<prefix>/lib/` plus the headers into
`<prefix>/include/`, so application makefiles link with plain
`-lSndKit` and include with `#import <SndKit/SndKit.h>`.

System package dependencies: `portaudio19-dev` (the audio I/O backend),
`libsndfile1-dev` (sound file formats), `libportmidi-dev` (headers for
the unused-by-Resound MIDI half). `libasound2-dev` is used by
portaudio's own build, not needed when linking the distro package.

Port patches (see `patches/`):
- `MusicKit-0001-vdsp-arch-guard.diff` wraps
  `Frameworks/SndKit/vDSP.c` (an x86-only SSE2 file) in an
  `__i386__`/`__x86_64__` guard so it compiles to an empty unit on other
  architectures (e.g. aarch64).
- `MusicKit-0002-portmidi-timeproc-cast.diff` casts the MIDI time
  callback to `PmTimeProcPtr` directly: the original cast to
  `long (*)(void *)` is an incompatible function pointer type, which
  clang 16+ rejects as an error (the developer machine's clang 14 only
  warned about it, which is how it slipped past the sandbox build).
- `MusicKit-0003-retrievedriverlist-advance.diff` fixes an upstream
  infinite loop: `retrieveDriverList` reuses one variable as both the
  device-table loop counter and the output-array write position, and
  only advances it for matching devices — so the first SndKit audio
  init hangs forever (100% CPU) on any machine with a playback-only
  or capture-only device (e.g. the Pi's HDMI cards). Full diagnosis in
  `docs/UPSTREAM_PATCHES.md` §3.
- `MusicKit-0004-streamrecorder-threshold.diff` re-exports
  `setStartTriggerThreshold:` on the `SndStreamRecorder` facade (it
  lived only on the internal processor): the recording flow needs a
  non-positive threshold to record from the first buffer.
- `MusicKit-0005-sndconvert-resample-buffer.diff` sizes the
  cross-rate conversion's temporary buffer for `resample()`'s
  `+ 1` output frame: the original expression truncates below the
  write for some input durations, overrunning the buffer and aborting
  in `free()`. Full diagnosis in `docs/UPSTREAM_PATCHES.md` §5.
- `MusicKit-0006-snd-initwithdata-64bit-swap.diff` swaps the six AU
  header fields of `-[Snd initWithData:]` (the pasteboard sound
  decode) with the 32-bit swap at the correct width and into their
  locals: on a 64-bit host the original 64-bit `long` swap
  zero-extends, so every pasteboard sound read decodes to nil (or to
  a 0-frame sound). Full diagnosis in `docs/UPSTREAM_PATCHES.md` §6.

The test tools (`test/`, `make -C test` builds `test/obj/`):

- `sndsmoke input.wav output.au` — exercises SndKit's libsndfile file
  I/O (load, write, reload) without any audio device or display.
- `resoundio input.wav workdir` — the 44-check contract suite for the
  `Snd (ResoundSound)` file-I/O category (compiled in), pinned
  test-first for Phase 1; headless.
- `resoundnib --check [roots …]` — verifies the converted `.gorm`
  asset format (the GNUstep archive magic + class descriptions, in the
  tree and the built bundle); headless.  `resoundnib --load` runs the
  runtime half (loads every `.gorm` in a child process); it needs a
  display, so CI runs `--check` and `--load` runs locally.
- `resoundmodule Zero.rmod` — the Phase 3 bundle-side load contract:
  the built `X.rmod` through `NSBundle` (the principal class via the
  generated `Info-gnustep.plist`, the menu tree the app's "Modules"
  menu is built from, `zeroSound:` over the five 1998 data formats);
  headless, Phase 3 onward.
- `resoundmenu [Resound.app] [--direct | --perform <title>]` — the
  Phase 3 app-side probe: loads the built app's main model the way
  `NSApplicationMain` does, then posts `NSApplicationDidFinishLaunching`
  (or calls the delegate directly with `--direct`) so the real launch
  path runs — including `ModuleController loadModules` — and dumps
  the main menu and the delegate's outlets; `--perform <title>`
  additionally performs the named module leaf's action (the
  user-click equivalent, for the lazy panel loads a menu dump
  cannot see) and dumps the window list.  Needs a display; CI runs
  it under `xvfb` against the in-tree `Resound.app` (non-fatal, like
  the launch check).

```sh
make -C test                                   # builds the five tools
LD_LIBRARY_PATH=<prefix>/lib \
  ./test/obj/sndsmoke test/Tone.wav /tmp/out.au   # .wav -> .au round trip
```

All five run headless except `--load` and `resoundmenu`; the first
three (`sndsmoke`, `resoundio`, `resoundnib --check`) plus
`resoundmodule` are fatal in CI, the two display tools non-fatal.

## Continuous integration (GitHub Actions)

`.github/workflows/build.yml` builds the app on every push. Because the
packaged GNUstep (apt) is built against GCC's `libobjc` - which lacks the
libobjc2/`gnustep-2.2` non-fragile ABI that the port (and SndKit) targets -
CI instead installs the GNUstep **stack from source** into a hermetic prefix
(`$GITHUB_WORKSPACE/gnustep`), the same combination as the Gershwin `/System`
reference install:

| component | source (pinned commit, see workflow) | build system |
|---|---|---|
| libobjc2 | `gnustep/libobjc2` @ `c9f4002a…` | CMake (`-DGNUSTEP_INSTALL_TYPE=SYSTEM`) |
| gnustep-make | `gnustep/tools-make` @ `4e31a031…` | autoconf (`--with-library-combo=ng-gnu-gnu --with-runtime-abi=gnustep-2.2`) |
| gnustep-base | `gnustep/libs-base` @ `5bda5222…` | autoconf (`--disable-libdispatch`) |
| gnustep-gui | `gnustep/libs-gui` @ `8f804fd5…` | autoconf |
| gnustep-back | `gnustep/libs-back` @ `bbcc3de7…` | autoconf |

These are the exact commits of the Gershwin reference install (see
`/Developer/Library/Repositories.csv` on the dev machine). The stack is
cached with `actions/cache` keyed on `GNUSTEP_STACK_REV`, so only the first
run per rev builds it (~20-30 min); later runs take a couple of minutes.
To update the stack: bump the pinned commits **and** `GNUSTEP_STACK_REV`
(invalidates the cache).

Build order matters: libobjc2 is built **first** (gnustep-make's configure
detects it, selects the `ng` runtime and links its blocks test against it);
the other components configure against the installed prefix via its
`GNUstep.sh` (export `GNUSTEP_CONFIG_FILE` to point at the prefix's
`etc/GNUstep/GNUstep.conf` on machines without a stock GNUstep).

The job then builds the SndKit chain from the `third_party/MusicKit`
submodule (`third_party/build-sndkit.sh`; the frameworks are installed
into the hermetic prefix **after** the stack is saved to the cache, so
every run rebuilds them fresh from the pinned submodule instead of
trusting a stale cached copy — a couple of minutes, while the expensive
stack stays cached). The gates, all fatal: `sndsmoke` (the SndKit file
I/O round trip), `resoundio` (the file-I/O contract suite), and
`resoundnib --check` (the `.gorm` asset format). Then `make -f
GNUmakefile` (in-tree, as locally), the Phase 3 module build +
install (`Zero.rmod` into the prefix's `lib/GNUstep/Resound`, fatal),
the Phase 3 `resoundmodule` load contract (fatal) and the
`resoundmenu` app-side probe under `xvfb` (non-fatal), a non-fatal
launch check under `xvfb` + `openbox` (the app starts with its 1998
main window and sits in its event loop until the 10 s timer; exit 124
is a pass), and a screenshot of the running app is published. The
built `Resound.app` is uploaded as a workflow artifact.

## Adding sources step by step

The bootstrap intentionally builds only the sources that are already
GNUstep-ready. When a file is ported (or verified portable), add it to the
source lists in `GNUmakefile`:

```make
Resound_OBJC_FILES= \
	Source/Resound_main.m \
	Source/Foo.m \          # <- add ported Objective-C files here
	...

Resound_C_FILES= \
	Source/fft.c \         # <- add ported C files here
	...
```

Guidelines:

- Sources keep their `Source/` paths; the build places objects in
  `obj/Resound.obj/Source/` accordingly.
- New resources (nibs once migrated, tiffs, docs) go into `Resources/` and
  are listed in `Resound_RESOURCE_FILES` (paths relative to `Resources/`).
- Do **not** reference files from the legacy `Resound.app/` directory; it is
  the build bundle now.
- After adding sources, rebuild and verify the app still launches
  (`./Resound.app/Resound` with a display attached). For any exercise
  of the audio path (play/record) from a non-session shell, also set
  `XDG_RUNTIME_DIR=/run/user/1000` so PortAudio reaches the desktop
  session's PipeWire/Pulse socket; the launch check itself does not
  need it (nothing initialises audio until a sound is played).

## Source classification status (2026-11-17)

Classification of the original Rhapsody app sources (the 26 `CLASSES` of the
Project Builder `Source/Makefile`, plus `Resound_main.m` and `fft.c`)
against the GNUstep toolchain:

### Ready (in the build)

| File | Notes |
|---|---|
| `Source/Resound_main.m` | trivial `NSApplicationMain`, unchanged |
| `Source/Extra.m` | compiles; one pre-existing warning (missing `%s` in a format string at line 49) |
| `Source/ModuleMenuNode.m` | compiles; one pre-existing selector-name warning |
| `Source/fft.c` | pure C, compiles (referenced by the FFT module, Phase 3) |
| `Source/Sound-ResoundSound.{h,m}` | **first SndKit-port file (2026-11-05, Phase 1, test-first)**: the `Snd (ResoundSound)` file-I/O category, extracted from `FileController.{h,m}` and migrated to SndKit (`initFromSoundfile:`-based loading, `setInfo:`/`writeSoundfile:`-based saving, `.~snd` backups, writer-format guard). Its intended behaviour is pinned by `test/resoundio.m` (44 checks, fatal in CI). The app links SndKit for it via `Resound_OBJC_LIBS`. |
| `Source/SoundManager.{h,m}` | **Phase 2, unit 1 (2026-11-06)**: the playback/recording manager, migrated to SndKit (`Sound` → `Snd`; performance-based `play`/`stop`/`pause`/`resume`/`record`; recording buffer sized at init via `initWithFormat:channelCount:frames:samplingRate:`; delegate `didPlay:` gains the SndKit `duringPerformance:` argument, new `hadError:`). Self-contained: the view ivar is `id` and the three app-header imports were dropped (those headers still import legacy SoundKit; re-add as they are ported), with file-scoped pragmas for the two warning classes the `id` dispatch produces. Eight **pre-existing** `-Wmissing-selector-name` warnings remain, from Sean Luke's 1998 `- record: (double) SoundRate: …` declaration idiom (verbatim from the original; the header/.m capitalisation difference proves the Rhapsody compiler used the same parameter-name reading as clang, so the runtime selector `record:::::` is preserved exactly — kept visible per the `Extra.m` precedent). **Phase 2, unit 1b (2026-11-06):** the recording flow is re-routed to `SndStreamRecorder` (SndKit's `Snd record:` is a stub): the capture runs to a temp `.wav` with a -1.0 trigger threshold (patch 0004), an app `NSTimer` enforces the legacy buffer-full duration (SndKit has no auto-stop), and `_finishRecording` (timer or `stop:`) reads the file back, converts it to the console-requested format (needs patch 0005 — the resample temp-buffer overflow), and does the legacy `didRecord:` handoff; `newSound` is now only the meter token. Verified at engine level (probe on the Pi) + app launch check. **2026-11-07 (console unit, unit 1c):** the `_finishRecording` implementation that unit-1b describes was missing from the committed file (declared in the header, called from `stop:` and the duration timer, never defined — a latent unrecognised-selector crash on any recording stop; `resoundio` has zero record coverage, so CI stayed green). It was re-implemented from the unit-1b design (one correction: `initFromSoundfile:` is an instance method — `[[Snd alloc] initFromSoundfile:]`) and the unit-1b flow is now exercised in-app by the console probe; the header's 1998 implicit-id `- dealloc;` became `- (void) dealloc;` to match the definition (a pre-existing `-Wmismatched-return-types`), leaving exactly the eight documented `-Wmissing-selector-name` warnings as the file's baseline. **2026-11-08 (view-chain follow-up):** the header's 1998 `#import "ResoundMiscSoundView.h"` is restored (1998 position) and the view ivar is the 1998 typed `ResoundMiscSoundView*` (the unit-1 `id`-for-now comment is removed); the five view sends resolve on SndKit's `SndView` declarations, and the file-scope `-Wobjc-multiple-method-names` suppression in the `.m` is dropped with the `Snd`-vs-`SndView` ambiguity its reason was (the `-Wobjc-method-access` one stays for the not-yet-migrated controller sends). The file's TU baseline moves 8 → 25 `-Wmissing-selector-name` (the eight 1998-idiom ones plus the view headers' re-emissions — `MiscSoundView.h` 8, `ResoundMiscSoundView.h` 9 — into the TU; zero other warning classes), and the full rebuild's total warning count moves 67 → 101 (100 `-Wmissing-selector-name` re-emissions of the documented 1998 idioms plus the one pre-existing `Extra.m` format warning; zero new classes). **Phase 3, module unit (2026-11-17):** the 1998 import block is complete again — the `ModuleController.h` import is unconditional (the SndKit-port header now compiles), and the port-added `NOT_COMPILING_WITH_MODULES` define/guard plus the `-Wobjc-method-access` pragma are removed: the 1998 file never had a switch, and with the module chain declared the pragma's reason is gone. The controller-chain sends (`soundDidPlay:` et al.) now resolve against the real `ModuleController` declarations; the file's own four `-Wmissing-selector-name` lines are unchanged, and the TU additionally re-emits the module headers' 1998 idioms (attributed to the headers, `ModuleController.h` 3 + `ModuleProtocol.h` 2). |
| `Source/ConsoleManager.{h,m}` | **Phase 2, unit 1c (2026-11-07)**: the record console, migrated to SndKit. The `NXSoundIn` device ivar becomes an `SndFormat input_format` ivar seeded from `[Snd nativeInputFormat]`; SndKit has no per-device gain/source/rate/encoding APIs, so the gain sliders are display-only, the rate menu is always user-defined (the native rate seeds the field and min/max labels; a stored rate wins and `SoundManager` resamples the capture to it in `_finishRecording`), and the encoding menu is a fixed table of the three capturable formats (16-bit/8-bit linear, µ-law — A-Law and AES were never usable in the 1998 file either). The 1998 `__BUILDING_RHAPSODY` define is kept (its `#ifndef` blocks — the app-icon light, the hidden window — were already dead in the 1998 Rhapsody build and stay dead; the `light` ivar is declared unconditionally, as the 1998 nib's class description lists it). The local `ConsoleFileController` protocol bridges the not-yet-migrated `FileController` (`currentSound:` — the file unit). The second bridge, `ConsoleSoundViewCompat` (the 1998 SoundView play-position API the console auto-scrolling needs), is dropped in the 2026-11-08 follow-up: the 1998 `ResoundMiscSoundView.h` import is restored (1998 position) and the two `cv` locals return to the 1998 untyped `id`, whose dispatch resolves against the view chain's own declarations. The 1998 six-argument `record:::::` call is byte-identical (the selector is preserved — see the `SoundManager` row). Compiles with zero new warnings (the four `-Wmissing-selector-name` from the `SoundManager.h` 1998 idiom remain in its output — documented there; the TU total is 21 after the follow-up's view-header import, all `-Wmissing-selector-name`). **Verified in-app** (headless probe): `[[ConsoleManager alloc] init]` (the in-app path; it loads the 1998 `Console.nib`), the manager wired to a fresh `SoundManager`, `recordDown:` → `SndStreamRecorder` capture of the silent virtual input (now also on the dev machine, not only the Pi) → user `stop:` at ~2 s → the restored `_finishRecording` (recorder stop, read-back, convert to 44.1 kHz/2 ch/linear-16, flag resets, temp-file/recorder/timer cleanup) — clean, no stray file, exit 0. The 1998 `Console.nib` itself **does not load** under the GNUstep reader; its converted `Console.gorm` twin does (the NIB conversion unit, 2026-11-08 — `docs/RESOUND_SNDKIT_PLAN.md`, NIB migration), and the console now loads in-app through `ResoundNibs`. |
| `Source/MiscVolumeMeter.{h,m}`, `Source/ResoundMiscVolumeMeter.{h,m}`, `Source/MiscSoundTracker.{h,m}` | **Phase 2, unit 1c (2026-11-07)**: the console's meter and second tracker, migrated to SndKit in the same unit — the 1998 `SoundMeter` casts become the migrated class names, the legacy `NX_Sound*` status groups map to `Snd isPlaying` / `SndPerformance isPaused` (the recording group is undetectable on an Snd — SndKit never records into one — and reports idle), and the 1998 `samplesProcessed` maps to the last performance's `samplesPerformedOfPerformance:`. Verified in-app by the same console probe (the meter receives the console's token sound during the capture). |
| `Source/ResoundNibs.{h,m}` | **NIB conversion unit (2026-11-08)**: the platform-aware nib-load helper (`+loadNibNamed:owner:` with the logical name, no extension) through which every nib-load call site in the tree now goes; resolves to the converted `.gorm` on GNUstep and the 1998 `.nib` on a native build (see `docs/RESOUND_SNDKIT_PLAN.md`, NIB migration). |
| `Source/MiscSoundView.{h,m}`, `Source/MiscSoundViewRuler.{h,m}`, `Source/ResoundMiscSoundView.{h,m}` | **Phase 2, view-chain unit (2026-11-08)**: the three core document views, migrated to SndKit on `SndView` (`SoundView`→`SndView`, `Sound*`→`Snd*`, `sampleCount`→`lengthInSampleFrames`, `SNDConvertDecibelsToLinear`, `setContinuous:`→`setContinuousSelectionUpdates:`, `NXSoundPboardType`→`SndPasteboardType`, `char*` info-string chain→`NSString*`; `ModuleSoundView.h`/`SelectionInspector.h` imports dropped — the latter is a legacy-SoundKit drag nothing in the file needs). Three platform rewrites (documented in `docs/RESOUND_SNDKIT_PLAN.md`): the ruler labels are drawn via `NSString` drawing (GNUstep has no `PSselectfont`/`PSstringwidth`), the 1998 `selectionRect` 1.1x fudge becomes a 10% wider frame selection (SndKit's `setSelection:` doesn't clamp; its `selectionRect` is a read-only derived method), and the 1998 buggy `pasteboard:provideData:` super call becomes the `provideDataForType:` it always should have been. `getSelection:size:` keeps the 1998 `int*` (the super call casts to SndKit's `unsigned int*` — an `unsigned int*` override would warn at every call site); `pasteboardChangedOwner:` stays byte-identical but GNUstep's `NSPasteboard` never sends it (no such symbol in `libgnustep-gui`), so the 1998 paste-bug retains accumulate (two per `cut:` — SndKit's `cut:` dispatches its internal `copy:` back into the 1998 override — plus one per `copy:`): documented difference, not a regression. The 1998 multi-arg `set:`/`update:` idiom is kept verbatim and is runtime-safe (registered `set:::::::::`/`update::::::::::`; the real callers' argument counts match); the 50 re-emitted `-Wmissing-selector-name` warnings are the file set's documented baseline (the `MiscSoundView.h` 8 re-emit into every TU importing it; zero other warning classes). Verified with a display probe (both display modes, the selection fudge, zoom 1/10/100/1000, ruler via the 1998 `set:` idiom incl. the NSString labels, pasteboard cut/copy/data materialisation, info chain, teardown — all pass, no exceptions) + all fatal gates green + app launch clean. |
| `Source/AttributesInspector.{h,m}`, `Source/EditController.{h,m}`, `Source/InfoStringInspector.{h,m}`, `Source/InspectorManager.{h,m}`, `Source/MarksInspector.{h,m}`, `Source/Module.{h,m}`, `Source/ModuleController.{h,m}`, `Source/ModuleSound.{h,m}`, `Source/ModuleSoundView.{h,m}`, `Source/SelectionInspector.{h,m}`, `Source/VolumeController.{h,m}`, `Source/ZoomInspector.{h,m}` | **SndKit-leftovers unit (2026-11-14)**: the twelve remaining `CLASSES` files (all but `PreferencesManager`) — with them, **25 of the 26 1998 `CLASSES` classes** are in the build. The mappings are the documented Phase-1 set (`docs/RESOUND_SNDKIT_PLAN.md`): the import swap to `<SndKit/SndKit.h>` (11 lines, incl. `ModuleSound.m`'s `<SoundKit/convertsound.h>`), the 1998 type renames (`Sound`→`Snd` / `SoundView`→`SndView`, incl. the `Snd(ModuleSound)` / `SndView(ModuleSoundView)` category headers and the `SndView**` of `newWindow:` in `ModuleController.{h,m}` + `ModuleProtocol.h`), `sampleCount`→`lengthInSampleFrames`, `convertToFormat:`→`convertToSampleFormat:`, the `char*` info-string chain→`NSString*` (`InfoStringInspector`'s `stringWithCString:`/`lossyCString` round-trips, the `ModuleSoundView` `info`/`setInfo:` pair — now matching the view chain), the functionally-dead `NXSoundOut*` ivar→`SndStreamMixer*` (alloc/release only; SndKit's `SndStreamMixer init` is light — no device enumeration), `SNDiMulaw`/`SNDMulaw`→`SndMuLawToLinear`/`SndLinearToMuLaw`, `[Sound setMute:]`→`[Snd setMute:]`, the bare `sound` ivar→`[self sound]`, the `getSelection:` `unsigned int*` casts (view-chain precedent), and the `<objc/List.h>` import dropped from `ModuleController.h` (absent from the GNUstep prefix; the 1998 `PAStringList` mention is a comment). SndKit keeps the rest of the 1998 API with identical values/signatures — all 24 `SND_FORMAT_*`/`SND_RATE_*` constants, `isEmpty`/`isPlayable`/`needsCompacting`/`compactSamples`, `displayMode` + the `NX_SOUNDVIEW_*` aliases — so those lines stay byte-identical. Three files (`InspectorManager`, `MarksInspector`, `Module`) use no legacy API and come in with the import swap alone. The nine main-model stubs in `ResoundMissingClasses.m` (the eight inspector/controller classes + `ZoomInspector`; `Module`/`ModuleSound`/`ModuleSoundView` never had stubs — the main model doesn't instantiate them) are retired with the unit; `test/GNUmakefile`'s `resoundnib` file list mirrors the app list (the twelve files added there) so `--load` resolves them. Warning baseline (gsbuild full build): 169 → 428 — the +257 are all `-Wmissing-selector-name`, the 1998 multi-arg idiom re-emitted from the migrated neighbour headers into the twelve new TUs (the documented inheritance, same class as the view-chain baseline: `ModuleSound.h` 10×, `ModuleController.h` 1×, `ModuleProtocol.h` 2×, plus the already-migrated `FileController.h`/`SoundManager.h`/`SoundDocumentTable.h`/view headers re-emitting). Two new single-instance warnings on 1998 byte-identical lines, documented baselines never fixed (the `Extra.m` precedent): `-Wparentheses` @ `ModuleSound.m:77` (the `nextPositivePowerOfTwo:` shift loop `for(t=0;value=value>>1;t++);`) and `-Wmisleading-indentation` @ `MarksInspector.m:160`. One port-side byproduct, suppressed with a file-scope pragma (the `SoundManager` pattern): `-Wobjc-multiple-method-names` @ `AttributesInspector.m` — the 1998 untyped `changeInfo:thisSound` receiver resolves against both SndKit's `Snd channelCount` and GNUstep's `GSSoundSource channelCount` (via AppKit). Verified: full build green; all fatal gates green (`sndsmoke`, `resoundio` 44/44, `resoundnib --check` 43/0); `resoundnib --load` 43/0 with a display; app launch clean — the main model now instantiates the real `EditController`/`InspectorManager`/five inspectors/`VolumeController`/`ModuleController`, the main window comes up viewable, zero class-not-found (the main model's `ModuleController` comes up as the real class; with the 1998 no-modules switch enabled since FU3, its `loadModules` call path was compiled out — the module system first runs for real with the Phase 3 module unit, see the modules section below). **Phase 3, module unit (2026-11-17):** no change to these files (the per-module header copies that unit syncs live in `Source/Modules/Zero/`); with the 1998 switch restored, the header re-emissions the 1998 idiom carries land in two more TUs (`FileController.m`, `SoundManager.m`): the attributed counts double, `ModuleController.h` 6 → 12 and `ModuleProtocol.h` 4 → 8, the +10 of the full-build total's 445 → 455 move (all `-Wmissing-selector-name`; the toolchain's serial-build history: 67 → 101 → 169 → 428 → 445 → 455). |
| `Source/PreferencesManager.{h,m}` | **Preferences unit (2026-11-14)**: the last of the 26 1998 `CLASSES` files — with it, **all 26 of 26** are in the build. The unit is **build wiring only**: `PreferencesManager.{h,m}` are byte-identical to 1998 and needed no change (nothing in it uses the legacy SoundKit API — its only 1998-adjacent dependency, `ResoundMiscSoundView.h` → `MiscSoundView.h`, was already migrated by the view-chain unit; the two non-1998 lines in the committed file are the `ResoundNibs` call-site mapping from the NIB-conversion unit, landed 2026-11-08). The wiring: `GNUmakefile` adds it to `Resound_OBJC_FILES`; its stub is deleted from `Source/ResoundMissingClasses.m` (which now stubs only the five nib-internal chain names with no source file in the tree — `ModuleControllerInstance`, `SoundManagerInstance`, `PreferencesManagerInstance`, `Inspector`, `ErrorHandler`); and `test/GNUmakefile` mirrors it into the `resoundnib` file list so `--load` resolves the real class. What it does: registers the 13 1998 preference defaults at init, lazily loads the `Preferences` nib from its `startPreferencesPanel:` menu action, and `preferencesOkayed:` (the 1998 "Set" button — the only action in that nib; the "Revert" button has none) saves the panel's current control state via `savePreferences` and deliberately leaves the panel open (the 1998 comment: "I *really* don't like closing the panel"). **Verified in the real app** (2026-11-14, the live GNUstep X session): the 1998 menu opens it (the full eight-menu main menu is intact at runtime; Preferences is the `Edit` item), the panel renders the pristine 1998 layout (322×469 — every control present: the five switches, the two radio groups, the two popups, the tick fields, Set/Revert), a click on **Set** writes all 13 defaults to `~/GNUstep/Defaults/Resound.plist` (GNUstep's `NSUserDefaults` flushes on the 30-second `GSHousekeeping` run-loop timer), and the app stays alive. Twelve of the thirteen round-trip exactly to the 1998 registered defaults; the one deviation, `PlayOnOpen` (registered `NO`, written `true`), is correct save behaviour, not a defect: the panel is a live control in a shared desktop session, the box was in the checked state when Set was pressed (a check is visible in the post-Set capture, unchecked in the on-open one), and `savePreferences` wrote the panel's actual state; the pre-test defaults file was restored afterwards. One documented, not-fixed behaviour difference: the 1998 Preferences key equivalent is `"!"` (Shift+1), which can never fire under GNUstep — `NSMenu -performKeyEquivalent:` compares the item's key equivalent against the event's `charactersIgnoringModifiers`, so the stored `"!"` never matches the typed `"1"`; the mouse path works and the nib keeps `"!"` + its modifier mask faithfully (the same applies to any 1998 menu item whose key equivalent is a shifted character). Gates: `resoundnib --check`/`--load` 57/0, `resoundio` 44/44, `sndsmoke`, full build exit 0 — all unchanged by the unit (the `--load` self-adapting expectation is untouched: a load failure only counts if every declared class resolves). Warning count: the unit's new TU re-emits the documented view-header idioms once each (`MiscSoundView.h` 8 + `ResoundMiscSoundView.h` 9, the same per-TU counts as the `SoundManager` TU) — the full-build total moves 428 → 445, zero new classes. |

### Every 1998 app source is in the build

With the Preferences unit (2026-11-14, row above) the final 1998
`CLASSES` file is in the build, so **all 26 of the 26** 1998 application
classes compile and link: the bootstrap four, the SoundManager/console/
view-chain units, the file unit's `FileController`/`SoundDocumentTable`/
`ResoundScrollView` (2026-11-09), the twelve `CLASSES` files of the
SndKit-leftovers unit, and the `PreferencesManager`.
`Source/ResoundMissingClasses.m` now stubs only the five nib-internal
names with no source file in the tree — the 1998 Rhapsody loader skipped
unknown classes the same way, and the 1998 code nil-guards every use.

One 1998 build switch is in force: `FileController`'s
`NOT_COMPILING_WITH_MODULES` is commented out, exactly as the 1998
release shipped it — the app builds with the module system, and
`applicationDidFinishLaunching` calls `[moduleController loadModules]`
(the modules section below; the port had enabled it as the no-modules
workaround until the module unit restored the shipped state).

### Not part of the app

- `Source/FileType.subproj/*` — Jerome Genest file readers (removed by
  decision; SndKit/libsndfile native readers instead, Phase 0 decision).
- `Source/MiscTapper.m`, `Source/MiscVolumeLight.m` — present in `Source/`
  but not in the original `CLASSES` list (MiscKit helpers; classified with
  the modules).
- `Source/streams/*` — NXStream patch (Phase 4).
- `Source/Modules/*` — the `.rmod` module frameworks (own build targets,
  Phase 3 — see the modules section below; `ResoundModules/*.rmod` are
  the 1998 built bundles, reference-only).

### Modules (Phase 3)

The 1998 modules are **runtime-loaded plugins**: Project Builder
"Loadable Bundle" directories (`BUNDLE_EXTENSION = rmod`, an executable
+ `Resources/`), enumerated at startup by the app's `ModuleController
loadModules` (every library domain + `/Resound`, plus the app bundle)
and instantiated through `NSBundle principalClass` (GNUstep's `NSBundle
load` dlopens the bundle executable; the classes register via the load
callback).  The recipe for building each module as a gnustep-make
bundle — with an explicit `NSPrincipalClass` in the generated
`Resources/Info-gnustep.plist`, the executable at the bundle root, the
bundle linking the SndKit chain itself — is **ADR 0020**.

**The Zero module unit (2026-11-17, first of the ten).**

- `Source/Modules/Zero/GNUmakefile` (new): the gnustep-make bundle
  building `Zero.rmod` in-tree; `make install` puts it in
  `$(GNUSTEP_LIBRARY)/Resound` — `<prefix>/lib/GNUstep/Resound` with
  the fhs filesystem layout (the CI, SYSTEM domain) or
  `~/GNUstep/Library/Resound` (USER domain) — where the app's search
  finds it at startup.
- `Source/Modules/Zero/ZeroModule.{h,m}`: the 1998 module class
  (133 lines, no nib), byte-identical to 1998 except the documented
  SndKit mappings (`docs/RESOUND_SNDKIT_PLAN.md`, Phase 3); its
  `Snd`/`SndView` category implementations come from the app binary
  (categories resolve per process).
- The three stale per-module header copies (`ModuleProtocol.h`,
  `ModuleSound.h`, `ModuleSoundView.h`) synced to the ported
  top-level files: the module `.m` files import their local copies
  (the 1998 layout); each remaining module syncs its own copies with
  its own unit.
- The 1998 per-module `Makefile`/`PB.project` pairs and the
  `Source/BuildModules`/`BuildFatModules` scripts stay for reference
  only (superseded by the GNUmakefiles, the way the 1998 app
  `Makefile` was).  The `ResoundModules/*.rmod` bundles are 1998
  big-endian binaries the GNUstep runtime cannot load (the way it
  cannot load the 1998 `.nib`) — reference-only.

**The Mix module unit (2026-11-18, second of the ten).**

- `Source/Modules/Mix/GNUmakefile` (new): the Zero template — the
  gnustep-make bundle building `Mix.rmod` in-tree (`MixModule` as the
  principal class, `ModuleInfo.rtfd` as the bundle resource, the
  SndKit chain linked per ADR 0020).
- `Source/Modules/Mix/MixModule.{h,m}`: the 1998 module class (no
  nib — the window half of the 1998 flow is the commented-out block
  anyway; the module uses only the `SndView` the app's `newWindow:`
  hands back).  The Zero mapping set (`Sound*`→`Snd*`,
  `sampleCount`→`lengthInSampleFrames` ×4, `data`→`bytes` ×2,
  `convertToFormat:`→`convertToSampleFormat:`, both
  `SNDSwap*ToHost` pairs deleted — SndKit is host-order) plus the
  Mix specifics: `NXSoundPboardType`→`SndPasteboardType` (both
  occurrences, incl. the dead `#ifdef PASTE_BUG` half),
  `int size, selection`→`unsigned int` (SndKit's `getSelection:`
  hands out unsigned; the 1998 `selection<0` guard half is dead for
  an unsigned, and clang's `-Wall` does not flag it, so it stays
  verbatim with a comment), `int ch,sa,df`→`int ch` (both `sa`/`df`
  fetches fed the deleted swaps; the one kept `ch = [[self sound]
  channelCount]` feeds the 1998 `num_bytes = ch`), and the 1998
  `tmprect` declaration gone (its only use is in the commented-out
  block; `-Wall -Wunused-variable`).  One addition beyond the
  mapping set, after the paste-vehicle conversion: `if ([s
  needsCompacting]) [s compactSamples];` — SndKit's zero-frame
  `[[Snd alloc] init]` buffer-list artifact: the paste is inserted
  *into* that buffer rather than replacing the sound, leaving a
  two-buffer sound whose buffer 0 is empty, and `-[Snd bytes]`
  reads buffer 0 (`docs/UPSTREAM_PATCHES.md`, the MusicKit-0006
  verification note; the artifact itself stays unpatched in SndKit).
  The µ-law case quotes the 1998 line: the 1998 `SNDMulaw` took the
  `int` sum and clipped inside, while SndKit's `SndLinearToMuLaw`
  takes a `short` — the port clips with SndKit's own `LINCLIP`
  first.  The 1998 `newWindow` call stays byte-identical (the
  finding below).
- The three stale per-module header copies synced to the ported
  top-level files (as Zero; the `ModuleController.h` copy keeps the
  1998 license-variant difference, as Zero's does).
- The bundle's build is the 1998 fingerprint and nothing else: 14
  warnings, all `-Wmissing-selector-name` re-emitted from the 1998
  headers, zero from `MixModule.m` itself.

**The 1998 no-space `newWindow:` declaration (a code fingerprint,
not a bug).**  `ModuleProtocol.h` (and the app-side
`FileController`/`ModuleController` declarations) carry
`- newWindow:(NSWindow**) theWindowPointer:(NSScrollView**)
theScrollViewPointer:(SndView**)theSoundViewPointer` — a type
immediately after each colon, the name before the next colon.
clang demotes those names to parameter names (the
`-Wmissing-selector-name` warning on every one of them — 442 of
the app build's 455 warnings are that idiom across the 1998
headers), so the method's runtime selector really is
`newWindow:::` — the exact selector the 1998 *unlabeled* calls
generate: `FileController.m`'s `[self newWindow:&win:&scrv:&sndv]`
and `MixModule.m:125`'s `[moduleController newWindow:
&tmpwindow:&tmpscrollview:&tmpsoundview]`.  The 1998 pair therefore
matches at compile and runtime with no adaptation anywhere (the
`resoundmodule` gate's fake controller re-declares the same no-space
shape, so its double carries the 1998 selector; the four
`-Wmissing-selector-name` warnings that costs in the gate build —
two declarations × two demoted names — are intentional and
documented in the file header).  Explicit empty
selector parts (`newWindow:::` in a declaration) are a parse
error, and labelling the calls would generate a *different*
selector than the 1998 declaration declares — both "fixes" would
break the 1998 match.

**The `resoundmodule` Mix contract.**  The tool dispatches on the
bundle's principal class (exactly what the app's `loadAModule:`
does): ZeroModule runs the Zero contract, MixModule the Mix
contract — principal class, the one-leaf "Mix In"→`mix:` menu tree,
then `mix:` through the duck-typed controller (injected by
`object_setIvar`, as Zero).  The mix cases cover what the 1998
`mix:` does: an **empty pasteboard** is a no-op (the flow finds no
sound type on the general pasteboard and must leave the document
untouched, while still reporting `soundChanged`) — this case runs
first, because the emptiness is a property of a fresh pasteboard
server, and GNUstep's `NSPasteboard` offers no `clearContents` to
reset it; then, for the five 1998 data formats in mono and stereo,
a source selection written to the general pasteboard the way a user
copy does (the real `SndView writeSelectionToPasteboard:`) and mixed
into a document selection (plus a truncated-paste variant: 30
frames into a 50-frame selection).  The expected document is the
pre-mix document with the pasted selection added — the paste hopped
through the same two `convertToSampleFormat:` calls the flow
performs (SndKit's own math, so the expectation mirrors the port
whatever its rounding does), and the add is the 1998 per-format DSP
(sample-indexed for the wide formats, byte-indexed for the 8-bit
ones — the buffer offsets the tool checks are converted to bytes).
The pasteboard needs no workflow plumbing: with no server running,
the client auto-launches a fresh `gpbs` (name transport is
filesystem-based — `$TMPDIR/NSMessagePort` — no other daemon), and
the server stops when the last client leaves.  One local caveat: a
desktop session's session manager keeps its own `gpbs` alive with
the session's clipboard contents, so local no-op verification
`pkill`s it first (CI runners have no such session).

**Verification.**  In CI the `Mix.rmod` build + install is fatal,
`resoundmodule` pins the bundle-side contract headlessly (the
principal class, the menu tree, the mix: no-op and the per-format
DSP over mono/stereo), and `resoundmenu` (non-fatal, under `xvfb`)
asserts the "Mix In" entry in the after-launch menu dump alongside
the "Zero" one.  Locally the same three plus the real-app run
(both modules installed: the launch panel, the Modules row, the bar
pixel-identical to the pre-module app as with Zero).  The app TU
total stays at the 455-warning baseline (the Mix unit touches no
app file — `FileController.m`'s `newWindow` pair is the 1998
fingerprint above, not a change).

**The Envelope module unit (2026-11-19, third of the ten) - and the
first with a control panel.**  The inventory's old "no nib" label
was wrong: `English.lproj/EnvelopePanel.nib` has been in the 1998
tree since day one (the NIB conversion unit produced the
`.gorm` twin, `480d227`/`79315f9`), and the NIB-era commits had
already switched the 1998 load call to the platform-aware helper:
`[ResoundNibs loadNibNamed:@"EnvelopePanel" owner:self]`
(`#import "ResoundNibs.h"`, kept).

- `Source/Modules/Envelope/GNUmakefile` (new): the Zero/Mix
  template — the gnustep-make bundle building `Envelope.rmod` in-tree
  (`EnvelopeModule` as the principal class, the SndKit chain linked
  per ADR 0020, `ModuleInfo.rtfd` as with Zero/Mix) plus the panel:
  `Envelope_RESOURCE_FILES` lists `English.lproj/EnvelopePanel.gorm`
  by its tree path; gnustep-make copies a `xxx/yyy` resource to the
  bundle's top-level `Resources` (the directory recursively), which
  is the placement the resolution below wants.  The 1998
  `English.lproj/EnvelopePanel.nib` folder stays in the tree as the
  migration source, uninstalled (the app's `Resources/` the same).
- `Source/Modules/Envelope/EnvelopeModule.{h,m}`: the 1998 module
  class (253 lines).  The header is unchanged (all outlets are
  `id`).  The `.m` is the Zero mapping set
  (`Sound`→`Snd`, `SoundView`→`SndView`, `data`→`bytes`, both
  `SNDSwap*` pairs deleted - SndKit is host-order; the 1998
  `sampleCount` fetch fed only those swaps, so the variable goes
  with them) plus the Envelope specifics: the 1998
  `SNDiMulaw`/`SNDMulaw` pair becomes SndKit's
  `SndMuLawToLinear`/`SndLinearToMuLaw` (the same sox libst
  routine) with explicit casts - and **no `LINCLIP`** (unlike Mix):
  the mu-law decode maxes out at 32124, which fits a `short`, and
  the fade multiplier is between 0.0 and 1.0, so the product can
  only shrink.  The 1998 `int firstSample, sampleLength` become
  `unsigned int` (SndKit's `getSelection:` hands out unsigned - the
  Mix adaptation; the `-Wpointer-sign` class otherwise).  One
  file-scope pragma, the app's `AttributesInspector` precedent for
  port-side byproducts: `-Wobjc-multiple-method-names` -
  `soundDidChange`'s untyped 1998 send `[[moduleController
  currentSound] channelCount]` (the protocol's implicit-id return)
  resolves against both SndKit's `Snd channelCount` and GNUstep
  AppKit's `GSSoundSource channelCount`; `applyEnvelope:` sends the
  same message at its typed `Snd*` current and is unambiguous, and
  the 1998 line itself stays byte-identical.
- The three stale per-module header copies synced to the ported
  top-level files (as Zero/Mix).
- The bundle build is the 1998 fingerprint and nothing else: 15
  warnings, all `-Wmissing-selector-name` re-emitted from the 1998
  headers, zero from `EnvelopeModule.m` itself (the Mix bundle's
  14, the same class).

**The panel-nib resolution (where the gorm must live).**  The 1998
load was the *class* method `+[NSBundle loadNibNamed:owner:]`
(Sean Luke's 1998 `Math` comment - "this only works because self is
the main class of the bundle!" - is the hint).  GNUstep implements
that class method in libs-gui's `NSBundleAdditions.m`: it resolves
the name against **the owning class's bundle first**
(`bundleForClass:[owner class]` - for the module, its own
`Envelope.rmod`), and only then against the main app bundle; the
path itself is `-pathForNibResource:` →
`-[NSBundle pathForResource:ofType:]`.  So the gorm must live in
the *module* bundle, where the 1998 nib did.  Inside the bundle,
however, it goes to the **resource root**, not the 1998
`English.lproj`: GNUstep's `pathForResource:ofType:` searches the
(non-localized) resource root first and then the lproj directories
of the `NSLanguages` preference - which carries short locale codes
(`"en"`), so the 1998 `"English.lproj"` directory name is never
matched and the lproj layout would be dead weight; the root
placement is locale-independent and is the way the app's own bundle
carries its gorm folders (`Resources/`, non-localized).  Verified
in the real app below: the installed bundle's root-level gorm is
found and the panel comes up.

**The `ResoundNibs` link boundary.**  Envelope is the first module
whose bundle references an *app* class (the nib-era load call):
the bundle carries an undefined `._OBJC_REF_CLASS_ResoundNibs`
class-reference symbol that its host process must provide.  The
app provides it (its six `ResoundNibs` call-site objects define
the reference), so the bundle loads there; the gate therefore
compiles the app's `../Source/ResoundNibs.m` into `resoundmodule`
(test/GNUmakefile) so the reference resolves in the gate process
exactly as it does in the app.  (Zero/Mix reference only the
`Module` base classes plus the SndKit/AppKit chain - all in linked
libraries - and needed no such addition.)

**The `resoundmodule` Envelope contract.**  As Zero/Mix, the tool
dispatches on the principal class (`EnvelopeModule` → the Envelope
contract): the one-leaf "Envelope"→`showEnvelopePanel:` menu tree,
then the contract through fakes injected by `object_setIvar`
(controller double + the panel's six outlets: duck-typed buttons
recording `state`/`enabled`, a matrix whose `selectedCell` is a
tag-settable cell (tag 0 = fade in, 1 = fade out), a panel
recording `orderFront:`).  Pre-setting the panel outlet skips the
nib load the module performs for a missing panel - a real load
needs a display, and the app-side half is the `--perform` probe
below.  `showEnvelopePanel:` must come up with the three channel
buttons selected, the enabled states following the sound's channel
count and the current window, and the panel ordered front (stereo
and mono documents).  `applyEnvelope:` then runs the fade DSP on
real in-memory Snds over the five 1998 data formats, mono and
stereo: a whole-sound selection fading in on both channels,
partial 50-frame selections on one channel each, in and out - the
expected buffer computed with the module's own per-format multiply
arithmetic (mu-law through the same SndKit pair, no clip - see
above), the faded range and the untouched rest checked
byte-for-byte.  The all button carries the state the app's panel
would have: 0 - the 1998 nib never connected `applyToAllButton`
(it is declared in the gorm's class description but the 1998
`objects.nib` wires only the other five outlets), so in the app it
stays `nil` and silently drops its `setState:`.  One last branch:
a 400001-frame mono sound (just past the 1998 `LOTS_OF_SAMPLES`
of 400000 × 1) must consult `runLongTimePanel` before the DSP.
277 checks in total, all passing; no pasteboard involved (the
1998 flow's `checkForCurrentDataOnPasteboard:` is a no-op in the
fake view).

**The `resoundmenu --perform` probe (new with the unit).**  A menu
dump cannot see the panel: the nib load is lazy - it runs on the
first click of the "Envelope" leaf, and a broken gorm placement
would surface only as the 1998 alert and a missing panel.  The
probe's `--perform <title>` flag performs the action of the item
titled `<title>` in the Modules submenu (the user-click
equivalent; the app menu's `Module Info` help entries carry the
same module titles, so the Modules submenu is searched first) and
then dumps the window list.  In the real app the Envelope case
resolves the full chain for real - installed `Envelope.rmod` →
`bundleForClass:` → root `Resources/EnvelopePanel.gorm` → gorm
load → the five outlet connections on the module → the panel
comes up **visible with the gorm's own title** "Envelope 1.0".
(One observation from the run: four additional hidden "Window"
scaffolding windows come up with the panel - the gorm carries
several window templates and the loader instantiates them all;
harmless.)

**Verification.**  In CI the `Envelope.rmod` build + install is
fatal; `resoundmodule` pins the bundle-side contract headlessly;
the `resoundmenu` probe (non-fatal, under `xvfb`) asserts the
"Envelope" entry in the after-launch menu **and** runs
`--perform Envelope`, asserting the "Envelope 1.0" window in the
after-perform dump.  Locally the same three plus `resoundnib
--check`/`--load` at 58 gorm folders, 0 failures (57 + the
bundle-side gorm copy, which the format gate now covers too) and
the real-app launch (all three modules installed: it stays up,
zero `objc-load` errors - the bundle's `ResoundNibs` reference
resolves against the app).  The app TU total stays at the
455-warning baseline (the unit touches no app file), and the
gate TU stays at its 18 (14 1998-header re-emissions + the four
intentional `newWindow` ones - the Envelope additions cost the
TU nothing new).

**The EchoChamber module unit (2026-11-19, fourth of the ten) —
and the second with a control panel.**

- `Source/Modules/EchoChamber/GNUmakefile` (new): the Zero/Mix
  template — the gnustep-make bundle building `EchoChamber.rmod`
  in-tree.  The principal class is **`EchoChamber`**, not the
  `XxxModule` pattern of the other nine (the 1998 Info carried no
  `NSPrincipalClass`; named explicitly, as in the other bundles,
  it lands in the generated `Info-gnustep.plist`).  `EchoChamber`
  is also the second nib'd module: `EchoChamber_RESOURCE_FILES`
  lists `ModuleInfo.rtfd` **and the `EchoChamber.gorm` directory**
  — the gorm is at the *module root* in the tree (no
  `English.lproj` wrapper, even less localized than Envelope's),
  and the 1998 bundle carried the nib at the bundle root too, so
  the root placement is the most faithful of the nib'd modules
  (the loader resolution is the Envelope finding: the owning
  class's bundle first, non-localized resource root first).  The
  1998 `EchoChamber.nib` folder stays in the tree as the
  migration source, uninstalled; the SndKit chain links per ADR
  0020.
- `Source/Modules/EchoChamber/EchoChamber.{h,m}` (163 lines):
  byte-identical to 1998 except — the import swap;
  `SND_RATE_HIGH` ×2 written out as `44100.0` with a comment
  (SndKit's `SND_RATE_*` defines live in MKPerformSndMIDI's
  `SndStruct.h`, **not** in the `SndKit.h` umbrella — a gap
  every remaining module will hit);
  `convertToFormat:`→`convertToSampleFormat:`; the
  `(Snd*)`/`(SndView*)` casts; `data`→`bytes` ×2; both
  `SNDSwap*` pairs deleted (host order, as in the earlier units);
  the 1998 `[[Sound alloc] init]` +
  `setDataSize:dataFormat:samplingRate:channelCount:infoSize:`
  (SndKit has no such setter) → the documented
  `initWithFormat:channelCount:frames:samplingRate:` initializer
  in the same size (the pre-check above the build leaves the sound
  mono/16/44.1k) plus `setInfo:` carrying the 1998 `infoSize`
  space over; and `[currentSound free]` → `[currentSound
  release]` — GNUstep's `NSObject -free` exists only to *raise*
  (`Use 'dealloc' instead of 'free'`), so the 1998 zone free
  becomes the MRC release; left as-is it would crash.  **And one
  non-negotiable:** the 1998 loop bound.  `datalength` is in
  *bytes*, so `for(x=1; x<=datalength/2; x++)` runs one sample
  past the end of *both* buffers — a latent 2-byte heap
  overflow the 1998 platform's malloc padding absorbed (the extra
  iteration only ever writes outside the sound's data; the
  audible samples are 1..N-1 either way).  SndKit buffers are
  exactly sized (`NSMutableData initWithLength:`) and modern glibc
  does not forgive it — the bound is tightened to
  `x<datalength/2`; the DSP processes identically.  (The
  remaining six modules' `dataSize`-indexed loops get the same
  scan with their units.)
- The three stale per-module header copies synced to the ported
  top-level files (as Envelope; the `ModuleController.h` copy
  keeps the 1998 license-variant difference).
- The bundle's build is the 1998 fingerprint and nothing else:
  18 warnings — the 1998-header re-emissions plus the
  `-Wobjc-multiple-method-names` on the `Snd`/`SndAudioBuffer`/
  `GSSoundSource` overlap the 1998 `ModuleSound.h` category
  brings (the app TU carries the same class in its 455 baseline).

**The gorm wiring (probed on the real installed bundle).**  A
throwaway probe loaded the bundle, instantiated the principal
class the way the app does, ran `ResoundNibs loadNibNamed:
@"EchoChamber" owner:` for real, and dumped the module's ivars:
the gorm connects all six declared outlets — `delay`/
`dropoff`/`initial` to *text field cells* (`NSTextFieldCell`),
`firstDelay`/`ratio` to *slider cells* (`NSSliderCell`), and
`EchoChamberPanel` to the panel (`NSPanel`, title **"Echo
Chamber"**); the five value controls' `takeFloatValueFrom:`
action connectors target the owner, which implements no such
selector anywhere in the module chain (the 1998 sliders' no-op
action — the values are read through the outlets at
`performEcho:` time, which is why the gate's fakes only answer
`floatValue`).  The gorm's "Echo Chamber" button targets the
module (the owner) with `performEcho:` — an explicit target,
not the responder chain.

**The `resoundmodule` EchoChamber contract.**  As Zero/Mix/
Envelope, the tool dispatches on the principal class
(`EchoChamber` → the echo contract): the one-leaf "Echo
Chamber..." (the 1998 three dots) → `begin:` menu tree; the
`moduleController` ivar plus the six outlet ivars checked to
exist and to start un-wired (all nil, `windowLoaded` 0);
`begin:` with the panel outlet pre-set to a fake and
`windowLoaded` pre-set via `object_setIvar` (skipping the nib
load, which needs a display — the app-side half is the probe
below), asserting the 1998 `makeKeyAndOrderFront:` on the fake
twice (the flag stays set, so the second call just re-orders
front); then `performEcho:` on real conforming Snds (mono,
16-bit linear, 44.1k — the one shape the 1998 method accepts
without its modal `NSRunAlertPanel` conversion prompt, which the
headless gate does not exercise, same policy as Envelope), the
five `floatValue` fakes, a view double recording the
`setSound:` hand-off and a controller double recording
`newSound:for:` (declared in the 1998 space-separated shape,
which clang parses as the clean `newSound:for:` — the exact
selector the 1998 labeled call generates, verified
empirically).  The expected buffer mirrors the ported DSP line
for line — including the tightened bound — and sample 0 of
the fresh sound stays zero (the 1998 loop starts at `x=1`;
SndKit's fresh buffer is zero-initialized), the original buffer
must carry the in-place echo, and the new sound must keep the
format/size/info string.  55 checks, 0 failures — three
shapes of the constants: both echo branches engaged, a zero
first delay (the addvalue branch from sample 1), and a sound
shorter than both delays (a pure copy).

**The `resoundmenu --perform` probe (extended with the unit).**
The after-launch Modules menu must show "Echo Chamber..." (along
side Mix In / Zero / Envelope), and `--perform "Echo
Chamber..."` drives the real `begin:` — the lazy gorm load
included — asserting the panel comes up **visible with the
gorm's own title** "Echo Chamber" (the probe run additionally
shows hidden scaffolding windows coming up with the panel, as
with Envelope — the gorm carries several window templates).

**Verification.**  In CI the `EchoChamber.rmod` build + install
is fatal; `resoundmodule` pins the bundle-side contract
headlessly; the `resoundmenu` probe (non-fatal, under `xvfb`)
asserts the after-launch menu entry **and** runs the second
`--perform`, asserting the "Echo Chamber" window.  Locally the
same three plus `resoundnib --check`/`--load` at **59** gorm
folders, 0 failures (58 + the bundle-side copy) and the
real-app launch with all four modules installed (it stays up,
zero `objc-load` errors).  The app TU total stays at the
455-warning baseline (the unit touches no app file), and the
gate TU stays at its 18 — the EchoChamber additions cost the
TU nothing new (one transient `-Wobjc-multiple-method-names`
the untyped `id` receiver caused is cast away).

**The Gate module unit (2026-11-20, fifth of the ten) — and the
third with a control panel.**

- `Source/Modules/Gate/GNUmakefile` (new): the Zero/Mix template
  — the gnustep-make bundle building `Gate.rmod` in-tree
  (`GateModule` as the principal class, `ModuleInfo.rtfd` as the
  bundle resource, the SndKit chain linked per ADR 0020) plus
  the panel: `Gate_RESOURCE_FILES` lists `ModuleInfo.rtfd` **and
  the `Gate.gorm` directory** — as with EchoChamber the gorm is at
  the *module root* in the tree (no `English.lproj` wrapper; the
  1998 `Gate.nib` folder sat at the bundle root too), and the
  1998 bundle carried the nib at the bundle root, so the root
  placement is the most faithful of the nib'd modules (the
  loader resolution: the Envelope finding).
- `Source/Modules/Gate/GateModule.{h,m}` (369 lines): the 1998
  module class.  The header is unchanged (all outlets are
  `id`).  The `.m` is the standard mapping set (import swap;
  `Sound*`→`Snd*`; `sampleCount`→`lengthInSampleFrames` — the
  variable stays, the whole-sound branch still uses it;
  `firstSample`/`sampleLength`→`unsigned int`; `data`→`bytes`;
  both `SNDSwap*` pairs deleted along with the swap-only
  `data8`/`data16`; `SNDiMulaw`/`SNDMulaw`→`SndMuLawToLinear`/
  `SndLinearToMuLaw` with explicit casts and **no `LINCLIP`** —
  the decode maxes out at 32124, which fits a `short`, and the
  gate's multiplier is between 0.0 and 1.0, so the product can
  only shrink, as in Envelope).  Two documented, not-fixed 1998
  fingerprints, carried as a note above the format switch: in
  the FLOAT/DOUBLE cases `abs(tempsnd)` truncates the sample to
  an integer before the threshold compare (the state machine
  runs on the integer part of the amplitude), and in the
  LINEAR_8 case `tempsnd` is `char` with `hi_clip = CHAR_MAX` —
  on a platform where char is unsigned (this one), the bytes
  read as 0..255 and the threshold is 127.5 instead of the 1998
  signed-char 63.5, so only the 1998 negative half of the 8-bit
  range can release the gate.  Both preserved byte-identical (no
  behavioural change).
- The three stale per-module header copies synced to the ported
  top-level files (as the earlier units).
- The bundle build is the 1998 fingerprint and nothing else:
  20 warnings — the 14 `-Wmissing-selector-name` re-emissions
  from the 1998 headers (`ModuleSound.h` 10, `ModuleMenuNode.h`
  2, `ModuleProtocol.h` 2) plus the six `-Wabsolute-value` on
  the `abs(tempsnd)` lines (the integer `abs` on a float in the
  FLOAT/DOUBLE cases, the no-effect `abs` on the `char` in
  LINEAR_8), zero other classes, zero from any other file.

**The gorm wiring (probed on the real installed bundle).**  A
throwaway probe loaded the bundle, instantiated `GateModule` the
way the app does, ran `ResoundNibs loadNibNamed: "Gate" owner:`
for real, and dumped the module's ivars: the gorm connects all
four declared outlets — `gatePanel` to the panel (`NSPanel`,
title **"Noise Gate"**), `thresholdField`/`secondsWaitField`/
`secondsCutField` to the three *text field views* (one per box
row; the module reads all three only through `floatValue`).
The panel's "Apply" control is a one-cell `NSMatrix` whose
cell carries no action of its own — the **matrix** holds the
action (`gateIt:`, explicit target: the owner, not the responder
chain).

**The `resoundmodule` Gate contract.**  As Zero/Mix/Envelope/
EchoChamber, the tool dispatches on the principal class
(`GateModule` → the gate contract): the one-leaf "Noise
Gate..." (the 1998 three dots) → `showNoiseGatePanel:` menu
tree; the `moduleController` ivar plus the four outlet ivars
checked to exist and to start un-wired (all nil), and the
`nib_loaded` flag checked to start unset.  `nib_loaded` is a
one-byte `BOOL` declared ahead of the four outlet pointers — a
pointer-sized `object_setIvar` on it would write into the
outlets' bytes, so the contract reads and writes it through the
type-encoding-aware sized ivar helpers.  `showNoiseGatePanel:`
with the panel pre-set to a fake and the flag pre-set (skipping
the nib load, which needs a display — the app-side half is the
probe below), asserting the 1998 `makeKeyAndOrderFront:` on the
fake twice (the flag stays set, so the second call just
re-orders front).  Then `gateIt:` on real in-memory Snds over
the five 1998 data formats, mono and stereo, a whole-sound
selection and a partial one: the pattern (a silent lead-in, a
loud run, a quiet tail) ramps and closes the per-channel gate
state machine the 1998 code runs — the three panel floats are
the 50/0.002/0.01 the module's own math turns into the
88/440-sample state counts (checked), and the expected buffer
mirrors the module's per-format DSP line for line, including
its `abs` (the raw calls stay in the module build; the mirror's
equivalent runs under a scoped pragma).  The gated range and the
untouched rest are checked byte-for-byte, and the samples must
sit in the zones the state machine implies — loud at or above
the threshold, the long quiet tail gated to silence — so a
common mistake in the module and its mirror could not hide
behind the equality alone.  205 checks, 0 failures; no
pasteboard involved (the 1998 flow's
`checkForCurrentDataOnPasteboard` is a no-op in the fake view).

**The `resoundmenu --perform` probe (extended with the unit).**
The after-launch Modules menu must show "Noise Gate..." (along
side Mix In / Zero / Envelope / Echo Chamber...), and
`--perform "Noise Gate..."` drives the real
`showNoiseGatePanel:` — the lazy gorm load included — asserting
the panel comes up **visible with the gorm's own title** "Noise
Gate".

**Verification.**  In CI the `Gate.rmod` build + install is
fatal; `resoundmodule` pins the bundle-side contract headlessly;
the `resoundmenu` probe (non-fatal, under `xvfb`) asserts the
after-launch menu entry **and** runs the third `--perform`,
asserting the "Noise Gate" window.  Locally the same three plus
`resoundnib --check`/`--load` at **60** gorm folders, 0
failures (59 + the bundle-side copy) and the real-app launch
with all five modules installed (it stays up, zero
`objc-load` errors).  The app TU total stays at the 455-warning
baseline (the unit touches no app file), and the gate TU stays
at its 18 — the Gate additions cost the TU nothing new (the
mirror's `abs` runs under the scoped pragma, and the 8-bit
pattern value was chosen to classify the same on any platform:
byte 0x80 is loud under either char signedness — +128 against
the char-unsigned 127.5 threshold, -128 in magnitude against
the signed-char 63.5 — while the quiet and silent levels sit
below it under either).

**The Filter module unit (2026-11-21, sixth of the ten) — and
the fourth with a control panel, and the first with two.**

- `Source/Modules/Filter/GNUmakefile` (new): the Zero/Mix/
  EchoChamber/Gate template — the gnustep-make bundle building
  `Filter.rmod` in-tree (`FilterModule` as the principal class,
  `ModuleInfo.rtfd` as the bundle resource, the SndKit chain
  linked per ADR 0020) plus the two panels: `Filter_RESOURCE_FILES`
  lists `ModuleInfo.rtfd` **and the `FilterModule.gorm` directory**
  — the gorm is at the *module root* in the tree (no
  `English.lproj` wrapper; the 1998 `FilterModule.nib` folder sat
  at the bundle root), the same placement as the other nib'd
  modules.
- `Source/Modules/Filter/FilterModule.{h,m}` (1998: 64/461 lines;
  ported: 64/526): the first nib'd module with *two* panels (the
  comb filter and the echo filter) and the first with a *submenu*
  in the module menu tree ("Filter" → "Comb Filter..." / "Echo
  Filter...").  The header is byte-identical to 1998.  Two 1998
  shapes carried deliberately: the olden-days all-caps naming (the
  header's note: methods, classes and instance variables all
  capitalized, never converted), and every method written with no
  space after the colon (`- LoadFilterPanel:sender`,
  `- Apply:sender`, ...): Clang reads the no-space `sender` as the
  parameter name, so each method's selector is the part before the
  colon — `LoadFilterPanel:`, `LoadEchoFilterPanel:`, `Apply:`,
  `ApplyEcho:`, ... — exactly what the gorm buttons and the 1998
  nib fire.  (That colon-abuts-the-name shape warns nothing; the
  app's `newWindow` warns because its no-space sits between the
  name and the colon instead.)  The `.m` is the standard mapping
  set: `NSBundle loadNibNamed:` → `ResoundNibs loadNibNamed:`;
  `Sound*`/`SoundView*` → `Snd*`/`SndView*`; `samplingRate !=
  SND_RATE_HIGH` → `!= 44100.0` (the 1998 constant is 44100 Hz,
  SndKit's rate is a double — the EchoChamber port made the same
  change); `convertToFormat:…samplingRate:` →
  `convertToSampleFormat:…` with the written-out rate (the 1998
  SoundView proper lacked the method — Resound's `ModuleSoundView`
  category supplied it, as the 1998 note says); `data` →
  `bytes`, `sampleCount` → `lengthInSampleFrames`; both
  `SNDSwap*` calls deleted (host order); the 1998
  `[[Sound alloc] init]` + `setDataSize:` pair replaced by the
  documented SndKit initializer in the same size, the info string
  carried over with `setInfo:` (the EchoChamber change).  The
  `PSWait()` progress-pump calls stay byte-identical — GNUstep's
  AppKit ships `PSWait` as a static inline no-op.
- Five documented, not-fixed 1998 fingerprints, kept
  byte-identical: the two zero-scans that walk off the 65-element
  stack array (an all-zero curve leaves `sum` at 0, which the comb
  loop divides by); the percent modulo that divides by
  `datalength/1000` (zero for a sound of fewer than 1000
  samples); the range test whose `<= 0` counts index 0 out of
  range (so the single center tap zeros frame 0 of the recursive
  copy); the echo's Max/Min strict-inequality clamp (an
  all-positive position matrix leaves `Min` at 0, an all-negative
  one leaves `Max` at 0); and the `PASTE_BUG` workaround blocks,
  left undefined as in the shipped 1998 build (the `NXUserAborted`
  checks never fire).
- The three stale per-module header copies synced to the ported
  top-level files (as the earlier units).
- The bundle build is the 1998 fingerprint and nothing else: 14
  warnings — the `-Wmissing-selector-name` re-emissions from the
  1998 headers (`ModuleSound.h` 10, `ModuleProtocol.h` 2,
  `ModuleMenuNode.h` 2), zero other classes, zero from
  `FilterModule.m` itself (the no-space `:sender` shapes warn
  nothing — see above).

**The gorm wiring (probed on the real installed bundle).**  A
throwaway probe loaded the bundle, instantiated `FilterModule` the
way the app does, ran `ResoundNibs loadNibNamed: "FilterModule"
owner:` for real, and dumped the module's ivars: the gorm connects
all eight declared outlets — `Sliders` to the 65-cell slider
`NSMatrix`, `Position`/`Amplitude` to the two 8-cell matrices,
`PercentDone`/`EchoPercentDone` to the two progress `NSTextField`s,
`FilterPanel`/`EchoFilterPanel` to the two panels (titles **"Comb
Filter"** / **"Echo Filter"**), `recursive` to the recursive/
non-recursive `NSButtonCell`.  The comb panel's "Apply" button
carries the action with the module as explicit target: **`Apply:`**
— the no-space 1998 shape's selector (the 1998 nib wires the same);
the echo panel's button carries `ApplyEcho:` (the gorm byte scan;
the bundle exports `-[FilterModule ApplyEcho:]`).  The
`WindowLoaded` flag — a full `int` in the 1998 header, not the
Gate's one-byte `BOOL` — starts unset, and a pointer-sized
`object_setIvar` on it is exact.

**The `resoundmodule` Filter contract.**  As the earlier five, the
tool dispatches on the principal class (`FilterModule` → the filter
contract): the menu tree — one "Filter" submenu holding exactly the
two leaves "Comb Filter..." / "Echo Filter...", each targeting the
module; the `moduleController` ivar plus the eight outlet ivars
checked to exist and to start un-wired (all nil), and the
`WindowLoaded` flag checked to start unset.  `LoadFilterPanel:` /
`LoadEchoFilterPanel:` with the flag pre-set (skipping the nib
load, which needs a display — the app-side half is the probe
below), asserting the 1998 `makeKeyAndOrderFront:` on the right
fake panel, the wrong one left alone, and repeatability (the flag
stays set, so the second call just re-orders front).  Then
`Apply:` / `ApplyEcho:` on the one sound shape the 1998 methods
accept without their modal conversion prompt (mono, 16-bit linear,
44.1k): six comb cases (the uniform 1/65 curve, the edge-zero 1/54
curve and the single center tap, recursive and non-recursive) and
two echo cases (all-positive / all-negative position matrices), the
expected buffers mirrored operation for operation — the signed-
short accumulator, the zero scans, the 1998 Max/Min clamp, the
`<= 0` range quirk — and the `setSound:`/`newSound:for:` hand-off
of the freshly built (resized) sound to the view and the
controller.  Beyond the byte match: the comb never amplifies (the
weights sum to 1), the center tap is the identity the quirk
punctuates (frame 0 zeroed recursive; 33 leading zeros + 32-frame
delay + 32 trailing zeros non-recursive), the all-positive echo
comes out with 27 leading zero frames (the clamped `Min`), the new
sound sizes are pinned (recursive keeps the length, the rest grows
by 64; the echo by `2·(-Min+Max)`), the percent fields end at 100,
and the `PASTE_BUG` counters stay at 0 (the workaround never
fires).  128 checks, 0 failures; no pasteboard involved (the fake
view's `checkForCurrentDataOnPasteboard:` is the no-op counter).

**The `resoundmenu --perform` probe (extended with the unit).**
The after-launch Modules menu must show the "Filter" submenu with
both leaves (alongside Zero / Mix In / Envelope / Echo Chamber... /
Noise Gate...), and `--perform "Comb Filter..."` /
`--perform "Echo Filter..."` drive the real `LoadFilterPanel:` /
`LoadEchoFilterPanel:` — the lazy gorm load included — asserting
the two panels come up **visible with the gorm's own titles**
"Comb Filter" / "Echo Filter".

**Verification.**  In CI the `Filter.rmod` build + install is
fatal; `resoundmodule` pins the bundle-side contract headlessly;
the `resoundmenu` probe (non-fatal, under `xvfb`) asserts the
after-launch submenu **and** runs the two `--perform`s, asserting
both panel windows.  Locally the same three plus
`resoundnib --check`/`--load` at **61** gorm folders, 0 failures
(60 + the bundle-side copy) and the real-app launch with all six
modules installed (it stays up, zero `objc-load` errors).  The app
TU total stays at the 455-warning baseline (the unit touches no
app file), the bundle TU is the 14 header re-emissions above, and
the contract TU stays at its 18 (the no-space mirror shapes warn
nothing).

**The 1998 no-modules switch (the "modules never loaded" root
cause).**  The 1998 release shipped `FileController.m` with
`NOT_COMPILING_WITH_MODULES` *commented out* (modules compiled in) and
`SoundManager.m` with no switch at all.  The port enabled both in file
unit FU3 (2026-11-09): `ModuleController.h` then could not compile
(`<objc/List.h>` is absent from the GNUstep prefix, and
`ModuleProtocol.h` still imported the legacy SoundKit umbrella), so
the app built as the 1998 no-modules variant — the `loadModules` call
path was compiled out and the module system never ran in the port.
The module unit restores the 1998-shipped state in both TUs (the
`#ifndef` guards in `FileController.m` stay, so the no-modules
variant remains a one-line change); both the SndKit-port
`ModuleController.h`/`ModuleProtocol.h` now compile, and
`applicationDidFinishLaunching` calls `[moduleController loadModules]`
as in 1998.

**Load-time behaviour (verified in the real app, 2026-11-17).**  With
`Zero.rmod` installed, every launch flashes the 1998 "Loading
Resound's Modules…" panel for about a second (a 1998 behaviour, gone
well before the 12 s CI capture), the bar's **Modules** row then
pops up its "[on] Zero" leaf, and the app menu's **Module Info**
submenu gains the help entry (`ModuleInfo.rtfd`).  The full
steady-state screen is **pixel-identical** to the pre-re-enable app
(`compare -metric AE` = 0), so the published README screenshot is
unchanged — the module becomes visible only on interaction.  The bar
row renders exactly as the 1998 release rendered it (dim, with the
submenu arrow): all eight 1998 bar items carry no action, so
GNUstep's `-[NSMenu _autoenableItem:]` computes *disabled* for every
one, and the 1998 `setAutoenablesItems:NO` freezes that state; the
bar's popup machinery opens the submenus regardless of the flag.
Documented, not fixed — that is the 1998 state, not a port defect.

**Verification.**  In CI the `Zero.rmod` build + install is fatal,
`resoundmodule` pins the bundle-side contract headlessly (the
principal class, the menu tree, `zeroSound:` over the five 1998 data
formats), and `resoundmenu` (non-fatal, under `xvfb`) runs the
app-side launch path against the in-tree `Resound.app` and asserts
the "Zero" entries in the dumped menu.  Locally the same three plus
the real-app run (launch panel, the Modules row click, the
pixel-identical bar).

## Notes

- The generated `Resound.app/Resources/Info-gnustep.plist` is produced from
  `Resound_PRINCIPAL_CLASS`, `Resound_APPLICATION_ICON`,
  `Resound_MAIN_MODEL_FILE` plus `ResoundInfo.plist` (plmerge). It is a
  build artifact; edit `ResoundInfo.plist` instead.
- The legacy NeXT-format `.nib` files in `Resources/` are **not** listed in
  `Resound_RESOURCE_FILES` for the GNUstep build: the GNUstep runtime cannot
  read the 1998 typed streams, so the bundle carries the converted
  `Resources/*.gorm` folders instead (one per `.nib`, sitting side by side
  with the originals, which stay as the migration source — see
  `docs/RESOUND_SNDKIT_PLAN.md`, NIB migration). Call sites load the
  logical name without extension through `Source/ResoundNibs.{h,m}`,
  which appends `.nib` on a native build, where the 1998 files would be
  listed instead. `Resound_MAIN_MODEL_FILE` is set to `Resound`: since
  the file unit (2026-11-09) the main model is live — the gorm loader
  resolves the 1998 class names to the real classes (file / console /
  sound-manager chain, the inspector and controller chain since the
  SndKit-leftovers unit, and the `PreferencesManager` since the
  preferences unit — every 1998 app class the main model instantiates
  is now real) and to the `ResoundMissingClasses.m` stubs (now only the
  five nib-internal chain names), so the app comes up with its 1998
  main window (verified: launch check in each unit, `resoundnib
  --load` 57/0).
- The Rhapsody `Source/Makefile` (Project Builder) is kept for reference and
  history; it is superseded by this build system on this branch.
- `GNUmakefile.postamble` carries a fallback for the bundle's `.desktop`
  file: the makefiles generate it with `pl2link`, which the current
  tools-make source releases and the Debian/Ubuntu packages do not ship.
  Where the tool is missing, the `.desktop` is produced from the Info plist
  instead (on systems with `pl2link`, such as the Gershwin `/System`
  install, the stock rule is used unchanged).
