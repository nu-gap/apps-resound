# 0020. Module builds: gnustep-make bundles with an explicit NSPrincipalClass

**Date:** 2026-11-17
**Status:** accepted

## Context

Phase 3 ports the ten `Source/Modules/**` implementations.  They are not
app code: the 1998 modules are **runtime-loaded plugins** — Project
Builder "Loadable Bundle" directories with a `BUNDLE_EXTENSION = rmod`
(executable + `Resources/`), enumerated at startup by the app's
`ModuleController loadModules` (every library domain + `/Resound`, plus
the app bundle) and instantiated through `NSBundle principalClass`.
The app-side loader is already ported; what the phase needs is the
GNUstep twin of each module's PB `Makefile`/`PB.project` pair.

The GNUstep counterpart of a 1998 Loadable Bundle is a gnustep-make
**bundle** (`bundle.make` rules; verified against the CI-pinned
`gnustep/tools-make` revision and the `gnustep/libs-base` `NSBundle`
source).  The Zero module — 133 lines, no nib, the plan's "simple
example module" — is the first unit and fixes the recipe the other
nine will follow.

There was a third problem: the ported app never *ran* its module
system.  The 1998 release shipped `FileController.m` with the
`NOT_COMPILING_WITH_MODULES` build switch **commented out** (modules
compiled in) and `SoundManager.m` with no switch at all (the module
import unconditional) — the port had *enabled* both, so the app built
as the 1998 no-modules variant and the `loadModules` call path was
dead.  (The original reason the port enabled them: `ModuleController.h`
then still imported `<objc/List.h>` and the legacy SoundKit umbrella,
neither of which the GNUstep prefix provides — both blockers are gone
with the SndKit port.)

## Decision

1. **Each module directory gets a gnustep-make `GNUmakefile`**
   (`include $(GNUSTEP_MAKEFILES)/bundle.make`) building the `X.rmod`
   in-tree, next to the PB files, which stay for reference only (the
   1998 `ResoundModules/*.rmod` bundles are big-endian binaries,
   likewise reference-only — the GNUstep runtime cannot load them, the
   way it cannot load the 1998 `.nib`).

2. **The principal class is named explicitly**: `Zero_PRINCIPAL_CLASS
   = ZeroModule`, which gnustep-make writes into the generated
   `Resources/Info-gnustep.plist` (with `NSExecutable = "Zero"`).
   The 1998 Info file carried no `NSPrincipalClass` and leaned on the
   NeXT runtime; the GNUstep `NSBundle principalClass` resolves it
   from the key (`NSClassFromString` after the dlopen), so the key
   must be present.  No custom plist file is needed — the per-instance
   variable feeds the auto-generated one.

3. **The executable lands in the bundle root** (`Zero.rmod/Zero`) —
   on a flattened tree that reproduces the 1998 layout exactly.
   `NSBundle`'s executable lookup tries
   `target_dir/library_combo/`, `target_dir/`, then the root, so the
   load survives an unflattened tree as well.

4. **Install destination is `$(GNUSTEP_LIBRARY)/Resound`**
   (`Zero_INSTALL_DIR`): the app's search path is every library
   domain + `/Resound`, so the module is found under either the SYSTEM
   domain (`<prefix>/lib/GNUstep/Resound` with the fhs filesystem
   layout, the CI) or the USER domain (`~/GNUstep/Library/Resound`,
   local).  Build side and runtime side resolve from the same source:
   gnustep-make's `filesystem.make` sets `GNUSTEP_LIBRARY` for the
   install, the installed `GNUstep.conf` carries the same value, and
   the app's `NSLibraryDirectory` search reads it.

5. **The module links the SndKit chain and the GNUstep libraries**
   via `Zero_BUNDLE_LIBS` (the Linux bundle link line uses
   `$(BUNDLE_LIBS)`, not the app-style `$(INSTANCE)_OBJC_LIBS`): the
   same flat set the app and the test tools link, so the module
   declares `SndLinearToMuLaw` et al. as proper `DT_NEEDED` entries
   instead of relying on lazy resolution from an app that happens to
   link them.

6. **The per-module header copies are synced to the ported
   top-level files.**  The 1998 tree duplicated `ModuleProtocol.h`,
   `ModuleSound.h`, `ModuleSoundView.h` (and `Module.h`,
   `ModuleMenuNode.h`, which were already identical) into every module
   directory, and the module `.m` files import their local copies.
   The three stale copies (legacy `SoundKit` imports, `Sound`/`Sound`
   types, `char*` info) now mirror `Source/{...}` byte for byte; the
   runtime category implementations still come from the app binary
   (categories resolve per process).  Each remaining module syncs its
   own copies with its own unit.

7. **The 1998 build switch is restored to the state the 1998 release
   shipped.**  `FileController.m`: `NOT_COMPILING_WITH_MODULES`
   commented out again (the `#ifndef` guards stay, so the no-modules
   variant remains a one-line change); the guarded blocks are live and
   `applicationDidFinishLaunching` calls `[moduleController
   loadModules]` as in 1998.  `SoundManager.m`: the port-added
   define/guard/pragma removed, the `ModuleController.h` import
   unconditional again (the 1998 file never had a switch).  Both TUs
   are back to the 1998 release state.

8. **Verification is three-tiered.**  In CI: the module build +
   install is **fatal** (a hard gate like the app build); the new
   headless tool `resoundmodule` (fatal, next to `sndsmoke`/
   `resoundio`/`resoundnib`) pins the bundle-side load contract: the
   built `Zero.rmod` through `NSBundle` — the principal class, the
   menu tree the app's "Modules" menu is built from, and `zeroSound:`
   driven over the five 1998 data formats (mono and stereo), the
   buffer checked to be exactly zeroed.  The new probe `resoundmenu`
   (non-fatal, under xvfb like the launch check) covers the
   app-side half for real: it loads the built app's main model the
   way `NSApplicationMain` does, posts
   `NSApplicationDidFinishLaunching` so the real launch path runs, and
   asserts the "Zero" entries appear in the dumped menu.  `resoundmodule`
   injects its duck-typed controller by setting the module's private
   `moduleController` ivar directly (`object_setIvar`): the app's
   `setModuleControllerTo:` enforces `ModuleProtocol` conformance,
   which a test double does not declare; the `zeroSound:` contract
   under test (read the ivar, operate on its sound) is the same
   either way.

## Consequences

- With `Zero.rmod` installed, the app starts with the "Modules" menu
  **live**: a real "Loading Resound's Modules..." panel flashes for
  about a second at every launch (a 1998 behaviour, gone well before
  the 12 s CI capture), and the **Modules** row's popup then offers
  the "[on] Zero" leaf, with the "Module Info" help entry (from
  `ModuleInfo.rtfd`) in the app menu.  The published README
  screenshot, however, is **unchanged**: the whole steady-state
  screen is pixel-identical to the pre-re-enable app (verified with
  `compare -metric AE` = 0) — the module only becomes visible on
  interaction.
- The bar rows render exactly as the 1998 release rendered them,
  dim, regardless of the module state.  Documented, not fixed: all
  eight 1998 bar items carry no action, so GNUstep's
  `-[NSMenu _autoenableItem:]` auto-computes *disabled* for every
  one, and the 1998 `setAutoenablesItems:NO` freezes that state;
  the bar's popup machinery opens the submenus regardless (click
  verified).  The enabled flag here reflects the 1998 model, not the
  port.
- The app build's warning count moves 445 → 455: the two TUs that
  now newly import the module headers re-emit the documented
  `-Wmissing-selector-name` class (`ModuleController.h` 6→12,
  `ModuleProtocol.h` 4→8 — each header's two importers doubled to
  four); no new warning class, and the port's `-Wobjc-method-access`
  pragma in `SoundManager.m` is gone with the switch.  History on
  this toolchain (clang 14 / aarch64): 67 → 101 → 169 → 428 → 445
  → 455 (serial `-j1` builds; parallel `-j` logs interleave the
  clang lines and must not be counted).
- The `X.rmod` name and the `*.rmod` filter in `ModuleController`
  stay exactly the 1998 ones; the loader itself needed no change for
  the port.
- The generated `Info-gnustep.plist` carries an empty `NSMainNibFile`
  (the bundle has no main model); nothing in `NSBundle` reads it — a
  cosmetic artifact of the generator, not a defect.
- The remaining nine modules follow this recipe one unit at a time;
  the nib'd ones (EchoChamber, FFT, Filter, Gate, Math,
  WaveBuilder) additionally carry their converted `.gorm` folders as
  bundle resources and compile their controller classes.
- The 1998 `Source/BuildModules`/`BuildFatModules` scripts and the
  per-module `Makefile`/`PB.project` pairs are kept for reference only
  (superseded, like the 1998 app `Makefile`); the Phase 4 checklist
  items that named them are resolved by this recipe.

## References

- `Source/Modules/Zero/GNUmakefile`, `Source/Modules/Zero/ZeroModule.{h,m}`,
  the synced `Source/Modules/Zero/{ModuleProtocol,ModuleSound,
  ModuleSoundView}.h` — the unit.
- `Source/FileController.m`, `Source/SoundManager.m` — the build
  switch, restored to the 1998-shipped state.
- `test/resoundmodule.m`, `test/resoundmenu.m`, `test/GNUmakefile` —
  the verification tier.
- `docs/GNUSTEP_BUILD.md` (modules section, and the
  `FileController`/`SoundManager` rows) — the file-by-file state.
- `docs/RESOUND_SNDKIT_PLAN.md`, Phase 3 — the phase this unit starts.
- `gnustep/tools-make` (CI-pinned revision): `bundle.make`,
  `Master/bundle.make`, `Instance/bundle.make`, `common.make`,
  `filesystem.make`, `target.make`, `Master/rules.make` — the recipe
  as built.
- `gnustep/libs-base` (CI-pinned revision), `Source/NSBundle.m` — the
  `principalClass` / `load` (dlopen) / executable / Info-file
  resolution this relies on.
- `gnustep/libs-gui` (CI-pinned revision), `Source/NSMenu.m`
  (`-_autoenableItem:`) — the bar's enabled-flag semantics above.
