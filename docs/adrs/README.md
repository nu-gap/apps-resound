# Architecture decision records

The decisions behind the GNUstep port, one record each.  Every ADR follows
the same shape: the context that forced the choice, the decision made, the
consequences the project now lives with, and pointers to where the full
evidence sits in the rest of the documentation.

The numbers are the **order the decisions were made**, not a ranking.
Statuses: **accepted** (in force) and **proposed** (documented intent; the
decision is still open).  Superseded records would be marked **superseded
by NNNN** rather than deleted.

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-replace-soundkit-with-sndkit.md) | Replace the defunct SoundKit with SndKit (Option B, full migration) | accepted |
| [0002](0002-pin-sndkit-to-git-tip.md) | Pin SndKit to the recent git tip, as the `third_party/MusicKit` submodule | accepted |
| [0003](0003-byte-identical-1998-sources.md) | Keep the 1998 sources byte-identical except for documented mappings | accepted |
| [0004](0004-unit-based-port.md) | Port unit by unit, each unit small and build-verified | accepted |
| [0005](0005-gnustep-make-gnumakefile.md) | Build with a gnustep-make `GNUmakefile`; the repository root is the application directory | accepted |
| [0006](0006-hermetic-ci-gnustep-stack.md) | CI builds a hermetic GNUstep stack from source (the Gershwin reference commits) | accepted |
| [0007](0007-fatal-headless-gates.md) | Three fatal headless gates in CI (`sndsmoke`, `resoundio`, `resoundnib --check`) | accepted |
| [0008](0008-convert-nibs-to-gorm.md) | Convert every NIB to `.gorm`; keep the 1998 folders side by side | accepted |
| [0009](0009-platform-aware-nib-loading.md) | Load nibs by logical name, resolving per platform (`ResoundNibs`) | accepted |
| [0010](0010-port-patches-for-pinned-deps.md) | Carry small port patches against the pinned dependencies | accepted |
| [0011](0011-deterministic-gorm-conversion.md) | Make the `.gorm` conversion deterministic (runtime serialization + converter walk) | accepted |
| [0012](0012-main-menu-renamed-to-nsmenu.md) | Rename the legacy main menu to `NSMenu` on conversion | accepted |
| [0013](0013-native-soundfile-readers.md) | Read sound files with the native SndKit/libsndfile readers, not the legacy readers | accepted |
| [0014](0014-writer-format-guard.md) | Normalize to 16-bit before writing (the writer-format guard) | accepted |
| [0015](0015-streamrecorder-app-driven-completion.md) | Record through `SndStreamRecorder`, with app-driven completion | accepted |
| [0016](0016-stub-unknown-model-classes.md) | Stub the classes the 1998 main model instantiates | accepted |
| [0017](0017-apache2-for-project-content.md) | Apache-2.0 for the project's own content; the 1998 components keep their notices | accepted |
| [0018](0018-ci-screenshot-scene-and-publish.md) | The README screenshot: a staged whole-screen CI scene, published to a `screenshot` branch | accepted |
| [0019](0019-module-dsp-architecture.md) | Module DSP architecture: real-time Audio Units, retained offline processing | **proposed** |
| [0020](0020-module-bundle-build.md) | Module builds: gnustep-make bundles with an explicit `NSPrincipalClass`; the 1998 no-modules switch restored to its shipped state | accepted |
| [0021](0021-openstep-string-encoding-per-system-version.md) | Decode the reader's strings per the archive's system version (1000+: UTF-8 with per-string NEXTSTEP fallback; below: NEXTSTEP only) | accepted |

## How the ADRs relate to the other documents

- `../RESOUND_SNDKIT_PLAN.md` — the audio-migration plan: the context and
  the phase structure ADRs 0001, 0002, 0013, 0014, 0015, and 0019 were
  made in; it keeps the granular status, the ADRs keep the decisions.
- `../GNUSTEP_BUILD.md` — the build system, the CI, and the file-by-file
  source classification behind ADRs 0003, 0005, 0006, and 0007.
- `../UPSTREAM_PATCHES.md` — the full patch records (symptom, explanation,
  diff, upstream status) behind ADRs 0010, 0011, and 0012.
- `../README_SCREENSHOT.md` — the screenshot pipeline behind ADR 0018.

A new ADR gets the next number whenever a new decision of this kind is
made — a replacement framework, a build-system change, a CI gate, a
forced mapping admitted into the 1998 sources, or an open question that
blocks a phase (and gets its status updated when it resolves).
