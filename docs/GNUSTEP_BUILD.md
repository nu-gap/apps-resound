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

The job then runs `make -f GNUmakefile` (in-tree, as locally) and finishes
with a non-fatal launch check under `xvfb` (the app has no main nib yet, so
"ran until the 10 s timer" counts as a pass). The built `Resound.app` is
uploaded as a workflow artifact.

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
  (`./Resound.app/Resound` with a display attached).

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

### Blocked by SoundKit (24 files, not in the build yet)

All 24 fail with `fatal error: 'SoundKit/SoundKit.h' file not found`
(directly or via their headers: `FileController.h`, `ConsoleManager.h`,
`MiscSoundView.h`, `MiscVolumeMeter.h`, `MiscSoundTracker.h`,
`SoundManager.h`, `SelectionInspector.h`, `SoundDocumentTable.h`,
`VolumeController.h`, `ModuleProtocol.h`, `ModuleSound.h`,
`ModuleSoundView.h`). They unblock with the SndKit migration
(`docs/RESOUND_SNDKIT_PLAN.md`, phases 1-3):

AttributesInspector, ConsoleManager, EditController, FileController,
InfoStringInspector, InspectorManager, MarksInspector, MiscSoundTracker,
MiscSoundView, MiscSoundViewRuler, MiscVolumeMeter, Module,
ModuleController, ModuleSound, ModuleSoundView, PreferencesManager,
ResoundMiscSoundView, ResoundMiscVolumeMeter, ResoundScrollView,
SelectionInspector, SoundDocumentTable, SoundManager, VolumeController,
ZoomInspector

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
