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
├── test/                     # sndsmoke SndKit smoke test (+ Tone.wav input)
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

Smoke test (`test/`):

```sh
make -C test                                   # builds test/obj/sndsmoke
LD_LIBRARY_PATH=<prefix>/lib \
  ./test/obj/sndsmoke test/Tone.wav /tmp/out.au   # .wav -> .au round trip
```

`sndsmoke` exercises SndKit's libsndfile file I/O (load, write, reload)
without any audio device or display, so it is safe to run headless; it
fails the build (CI) if the framework is broken.

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
stack stays cached), runs the `test/sndsmoke` SndKit smoke test (fatal),
runs `make -f GNUmakefile` (in-tree, as locally), and finishes with a
non-fatal launch check under `xvfb` + `openbox` (the app has no main
nib yet, so "ran until the 10 s timer" counts as a pass). The built
`Resound.app` is uploaded as a workflow artifact.

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

## Source classification status (2026-11-02)

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
| `Source/SoundManager.{h,m}` | **Phase 2, unit 1 (2026-11-06)**: the playback/recording manager, migrated to SndKit (`Sound` → `Snd`; performance-based `play`/`stop`/`pause`/`resume`/`record`; recording buffer sized at init via `initWithFormat:channelCount:frames:samplingRate:`; delegate `didPlay:` gains the SndKit `duringPerformance:` argument, new `hadError:`). Self-contained: the view ivar is `id` and the three app-header imports were dropped (those headers still import legacy SoundKit; re-add as they are ported), with file-scoped pragmas for the two warning classes the `id` dispatch produces. Eight **pre-existing** `-Wmissing-selector-name` warnings remain, from Sean Luke's 1998 `- record: (double) SoundRate: …` declaration idiom (verbatim from the original; the header/.m capitalisation difference proves the Rhapsody compiler used the same parameter-name reading as clang, so the runtime selector `record:::::` is preserved exactly — kept visible per the `Extra.m` precedent). **Phase 2, unit 1b (2026-11-06):** the recording flow is re-routed to `SndStreamRecorder` (SndKit's `Snd record:` is a stub): the capture runs to a temp `.wav` with a -1.0 trigger threshold (patch 0004), an app `NSTimer` enforces the legacy buffer-full duration (SndKit has no auto-stop), and `_finishRecording` (timer or `stop:`) reads the file back, converts it to the console-requested format (needs patch 0005 — the resample temp-buffer overflow), and does the legacy `didRecord:` handoff; `newSound` is now only the meter token. Verified at engine level (probe on the Pi) + app launch check. **2026-11-07 (console unit, unit 1c):** the `_finishRecording` implementation that unit-1b describes was missing from the committed file (declared in the header, called from `stop:` and the duration timer, never defined — a latent unrecognised-selector crash on any recording stop; `resoundio` has zero record coverage, so CI stayed green). It was re-implemented from the unit-1b design (one correction: `initFromSoundfile:` is an instance method — `[[Snd alloc] initFromSoundfile:]`) and the unit-1b flow is now exercised in-app by the console probe; the header's 1998 implicit-id `- dealloc;` became `- (void) dealloc;` to match the definition (a pre-existing `-Wmismatched-return-types`), leaving exactly the eight documented `-Wmissing-selector-name` warnings as the file's baseline. |
| `Source/ConsoleManager.{h,m}` | **Phase 2, unit 1c (2026-11-07)**: the record console, migrated to SndKit. The `NXSoundIn` device ivar becomes an `SndFormat input_format` ivar seeded from `[Snd nativeInputFormat]`; SndKit has no per-device gain/source/rate/encoding APIs, so the gain sliders are display-only, the rate menu is always user-defined (the native rate seeds the field and min/max labels; a stored rate wins and `SoundManager` resamples the capture to it in `_finishRecording`), and the encoding menu is a fixed table of the three capturable formats (16-bit/8-bit linear, µ-law — A-Law and AES were never usable in the 1998 file either). The 1998 `__BUILDING_RHAPSODY` define is kept (its `#ifndef` blocks — the app-icon light, the hidden window — were already dead in the 1998 Rhapsody build and stay dead; the `light` ivar is declared unconditionally, as the 1998 nib's class description lists it). Two local protocols bridge the not-yet-migrated neighbours: `ConsoleFileController` (`currentSound:` — `FileController` is the file unit) and `ConsoleSoundViewCompat` (the 1998 SoundView play-position API the console auto-scrolling needs; the view-chain unit implements it on `SndView`). The 1998 six-argument `record:::::` call is byte-identical (the selector is preserved — see the `SoundManager` row). Compiles with zero new warnings (the four `-Wmissing-selector-name` from the `SoundManager.h` 1998 idiom remain in its output — documented there). **Verified in-app** (headless probe): `[[ConsoleManager alloc] init]` (the in-app path; it loads the 1998 `Console.nib`), the manager wired to a fresh `SoundManager`, `recordDown:` → `SndStreamRecorder` capture of the silent virtual input (now also on the dev machine, not only the Pi) → user `stop:` at ~2 s → the restored `_finishRecording` (recorder stop, read-back, convert to 44.1 kHz/2 ch/linear-16, flag resets, temp-file/recorder/timer cleanup) — clean, no stray file, exit 0. The 1998 `Console.nib` itself **does not load** under the GNUstep reader (the manager's outlets stay nil and the console is nil-safe) — the NIB→Gorm/OpenStep-4.2 conversion package (`docs/RESOUND_SNDKIT_PLAN.md`) is the confirmed prerequisite for the console UI in-app. |
| `Source/MiscVolumeMeter.{h,m}`, `Source/ResoundMiscVolumeMeter.{h,m}`, `Source/MiscSoundTracker.{h,m}` | **Phase 2, unit 1c (2026-11-07)**: the console's meter and second tracker, migrated to SndKit in the same unit — the 1998 `SoundMeter` casts become the migrated class names, the legacy `NX_Sound*` status groups map to `Snd isPlaying` / `SndPerformance isPaused` (the recording group is undetectable on an Snd — SndKit never records into one — and reports idle), and the 1998 `samplesProcessed` maps to the last performance's `samplesPerformedOfPerformance:`. Verified in-app by the same console probe (the meter receives the console's token sound during the capture). |

### Blocked by SoundKit (19 files, not in the build yet)

All 19 fail with `fatal error: 'SoundKit/SoundKit.h' file not found`
(directly or via their headers: `FileController.h`, `MiscSoundView.h`,
`SelectionInspector.h`, `SoundDocumentTable.h`,
`VolumeController.h`, `ModuleProtocol.h`, `ModuleSound.h`,
`ModuleSoundView.h`). They unblock with the SndKit migration
(`docs/RESOUND_SNDKIT_PLAN.md`, phases 1-3):

AttributesInspector, EditController, FileController,
InfoStringInspector, InspectorManager, MarksInspector,
MiscSoundView, MiscSoundViewRuler, Module,
ModuleController, ModuleSound, ModuleSoundView, PreferencesManager,
ResoundMiscSoundView, ResoundScrollView,
SelectionInspector, SoundDocumentTable, VolumeController,
ZoomInspector

(FileController no longer contains the `Snd (ResoundSound)` category or
the legacy reader imports; those moved to
`Source/Sound-ResoundSound.{h,m}` / were dropped with the SndKit port —
the class itself remains blocked with the Phase 2 GUI chain.)

### Not part of the app

- `Source/FileType.subproj/*` — Jerome Genest file readers (removed by
  decision; SndKit/libsndfile native readers instead, Phase 0 decision).
- `Source/MiscTapper.m`, `Source/MiscVolumeLight.m` — present in `Source/`
  but not in the original `CLASSES` list (MiscKit helpers; classified with
  the modules).
- `Source/streams/*` — NXStream patch (Phase 4).
- `Source/Modules/*` — the `.rmod` module frameworks (own build targets,
  Phase 3; `ResoundModules/*.rmod` are the built bundles).

## Notes

- The generated `Resound.app/Resources/Info-gnustep.plist` is produced from
  `Resound_PRINCIPAL_CLASS`, `Resound_APPLICATION_ICON`,
  `Resound_MAIN_MODEL_FILE` plus `ResoundInfo.plist` (plmerge). It is a
  build artifact; edit `ResoundInfo.plist` instead.
- The legacy NeXT-format `.nib` files in `Resources/` are **not** listed in
  `Resound_RESOURCE_FILES` yet: they need the NIB migration work package
  (see `docs/RESOUND_SNDKIT_PLAN.md`). `Resound_MAIN_MODEL_FILE` (i.e.
  `NSMainNibFile`) is therefore empty for now and the app launches with no
  main window.
- The Rhapsody `Source/Makefile` (Project Builder) is kept for reference and
  history; it is superseded by this build system on this branch.
- `GNUmakefile.postamble` carries a fallback for the bundle's `.desktop`
  file: the makefiles generate it with `pl2link`, which the current
  tools-make source releases and the Debian/Ubuntu packages do not ship.
  Where the tool is missing, the `.desktop` is produced from the Info plist
  instead (on systems with `pl2link`, such as the Gershwin `/System`
  install, the stock rule is used unchanged).
