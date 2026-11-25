# Tests for the SndKit integration, the Resound file-I/O port and the
# converted NIB assets, and the Phase 3 modules.
#
# Builds:
#   - sndsmoke: exercises SndKit's libsndfile-backed file I/O
#     (load .wav -> write .au -> reload) without any audio device.
#   - resoundio: pins the intended behaviour of the Sound
#     (ResoundSound) category (Source/Sound-ResoundSound.m, compiled
#     into the tool) - the test-driven Phase 1 of the port (see
#     docs/RESOUND_SNDKIT_PLAN.md).
#   - resoundnib: gates the 1998 .nib -> .gorm conversion assets and
#     the ResoundNibs loading path (see docs/RESOUND_SNDKIT_PLAN.md,
#     NIB migration section).  --check is headless and runs in CI;
#     --load needs a display and runs locally (one child process per
#     gorm).
#   - resoundmodule: the Phase 3 load contracts of the ported modules
#     (docs/GNUSTEP_BUILD.md, modules): dispatches on the bundle's
#     principal class, like the app's loadAModule: - ZeroModule runs
#     the Zero contract (the built Zero.rmod through NSBundle, menu
#     tree, zeroSound: over the five 1998 data formats, mono and
#     stereo), MixModule the Mix contract (the "Mix In" menu tree,
#     mix: with an empty pasteboard no-op, then the per-format mix
#     with a pasteboard source selection), EnvelopeModule the Envelope
#     contract (the "Envelope" menu tree, showEnvelopePanel: with the
#     panel outlets as fakes, then applyEnvelope: - the fade in/out
#     DSP - over the five 1998 data formats, mono and stereo),
#     EchoChamber the EchoChamber contract (the "Echo Chamber..."
#     menu tree, begin: with the panel outlet as a fake and the
#     windowLoaded flag pre-set, then performEcho: - the echo DSP -
#     on conforming mono/16-bit/44.1k sounds, the one shape the 1998
#     method accepts without its modal conversion prompt),
#     GateModule the Gate contract (the "Noise Gate..." menu tree,
#     showNoiseGatePanel: with the panel outlets as fakes and the
#     nib_loaded flag pre-set, then gateIt: - the noise gate DSP -
#     over the five 1998 data formats, mono and stereo, whole-sound
#     and partial selections), FilterModule the Filter contract (the
#     "Filter" submenu with the two leaves, LoadFilterPanel: /
#     LoadEchoFilterPanel: with the WindowLoaded flag pre-set, then
#     Apply: / ApplyEcho: - the comb and echo filter DSP - on the
#     one sound shape the 1998 methods accept without their modal
#     conversion prompt, mono 16-bit 44.1k), WaveBuilderModule the
#     WaveBuilder contract (the "Generate Sounds" submenu with the
#     two leaves, loadSinPanel: / loadOthersPanel: with the
#     windowLoaded flag pre-set, then generateSin: / generateOthers:
#     - the sine and waveform generation - building a fresh 16-bit
#     mono 44.1k sound from the panel values, the brandNewSound:
#     hand-off, and the note actions' string writes).
#     Headless; the mix cases use the general pasteboard, which
#     GNUstep's client auto-serves with a fresh gpbs when no server
#     runs (the Envelope, EchoChamber, Gate, Filter and WaveBuilder
#     cases touch no pasteboard at all).
#
# sndsmoke, resoundio and resoundmodule run headless (no audio
# device, no display) and are fatal in CI; resoundnib --check is
# headless and fatal, --load needs a display.
#
# Prerequisite: the SndKit chain installed into the active GNUstep
# prefix (see ../third_party/build-sndkit.sh).

# Build the tool instances serially.
#
# gnustep-make (strict v2) runs one sub-make per tool, in parallel.
# Three of the tools below compile sources from the shared ../Source
# directory, and those object files land in the SAME real directory
# (obj/Source) reached via two different path strings
# (obj/<tool>.obj/../Source).  Make does not normalise "..", so it
# runs the directory-creation rule for both strings at once; the rule
# calls mkinstalldirs, which tests for existence and then creates
# non-atomically (TOCTOU), and the losing call fails with
# 'mkdir: ... File exists' on a fresh parallel build - a flake that
# hit CI on 2026-11-09 (5/10 locally).  Serialising the instances
# removes the race; each instance still compiles its own files in
# parallel, so the cost is a couple of seconds.
.NOTPARALLEL:

include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DOMAIN =	SYSTEM

TOOL_NAME = sndsmoke resoundio resoundnib resoundmodule resoundmenu

sndsmoke_OBJC_FILES = sndsmoke.m

resoundio_OBJC_FILES = resoundio.m ../Source/Sound-ResoundSound.m

# The NIB tests compile the ported app sources the way the app does
# (minus Resound_main.m, whose NSApplicationMain the test replaces):
# that is what makes the console and the main model fully loadable
# under --load - the main model needs the file unit's classes plus
# the SndKit-leftovers unit's twelve inspector/controller classes
# and the PreferencesManager, and the ResoundMissingClasses stubs
# (see there), which now stand in only for the nib-internal chain
# names.
resoundnib_OBJC_FILES = resoundnib.m \
	../Source/ResoundNibs.m \
	../Source/Extra.m \
	../Source/ModuleMenuNode.m \
	../Source/Sound-ResoundSound.m \
	../Source/SoundDocumentTable.m \
	../Source/FileController.m \
	../Source/ResoundScrollView.m \
	../Source/ResoundMissingClasses.m \
	../Source/SoundManager.m \
	../Source/MiscVolumeMeter.m \
	../Source/ResoundMiscVolumeMeter.m \
	../Source/MiscSoundTracker.m \
	../Source/ConsoleManager.m \
	../Source/MiscSoundView.m \
	../Source/MiscSoundViewRuler.m \
	../Source/ResoundMiscSoundView.m \
	../Source/AttributesInspector.m \
	../Source/EditController.m \
	../Source/InfoStringInspector.m \
	../Source/InspectorManager.m \
	../Source/MarksInspector.m \
	../Source/Module.m \
	../Source/ModuleController.m \
	../Source/ModuleSound.m \
	../Source/ModuleSoundView.m \
	../Source/PreferencesManager.m \
	../Source/SelectionInspector.m \
	../Source/VolumeController.m \
	../Source/ZoomInspector.m

resoundnib_C_FILES = ../Source/fft.c

# The module test compiles the module base classes the app provides
# (../Source/Module.m, ../Source/ModuleMenuNode.m - the bundles under
# test supply the module classes themselves); it imports the
# app's ../Source/Module.h and carries minimal local mirrors of the
# module headers instead (the module directories' header copies would
# reach the base classes through a second path, which #import would
# reject as duplicate interface definitions).  It also compiles in
# the app's nib loader (../Source/ResoundNibs.m): the Envelope
# bundle references the ResoundNibs class for its lazy panel load,
# and the app binary links it - the gate does the same so the
# reference resolves in the gate process exactly as it does in the
# app.  The shared ../Source include path serves the quoted imports,
# as for resoundio.
resoundmodule_OBJC_FILES = resoundmodule.m \
	../Source/Module.m \
	../Source/ModuleMenuNode.m \
	../Source/ResoundNibs.m

# The menu diagnostic compiles the full app the way the app does
# (minus Resound_main.m), loads the main model, and posts
# applicationDidFinishLaunching so the real module-load path runs.
resoundmenu_OBJC_FILES = resoundmenu.m \
	../Source/ResoundNibs.m \
	../Source/Extra.m \
	../Source/ModuleMenuNode.m \
	../Source/Sound-ResoundSound.m \
	../Source/SoundDocumentTable.m \
	../Source/FileController.m \
	../Source/ResoundScrollView.m \
	../Source/ResoundMissingClasses.m \
	../Source/SoundManager.m \
	../Source/MiscVolumeMeter.m \
	../Source/ResoundMiscVolumeMeter.m \
	../Source/MiscSoundTracker.m \
	../Source/ConsoleManager.m \
	../Source/MiscSoundView.m \
	../Source/MiscSoundViewRuler.m \
	../Source/ResoundMiscSoundView.m \
	../Source/AttributesInspector.m \
	../Source/EditController.m \
	../Source/InfoStringInspector.m \
	../Source/InspectorManager.m \
	../Source/MarksInspector.m \
	../Source/Module.m \
	../Source/ModuleController.m \
	../Source/ModuleSound.m \
	../Source/ModuleSoundView.m \
	../Source/PreferencesManager.m \
	../Source/SelectionInspector.m \
	../Source/VolumeController.m \
	../Source/ZoomInspector.m

resoundmenu_C_FILES = ../Source/fft.c

resoundmenu_TOOL_LIBS = -lSndKit -lMKPerformSndMIDI \
                        -lgnustep-gui -lgnustep-base -lstdc++ -lm

# The contract tests compile the category straight from the app tree;
# its header is needed for the quoted import in resoundio.m.
# (Global on purpose: gnustep-make strict v2 does not honour the
# per-product *_ADDITIONAL_INCLUDE_DIRS form.)
ADDITIONAL_INCLUDE_DIRS = -I../Source

sndsmoke_TOOL_LIBS = -lSndKit -lMKPerformSndMIDI \
                     -lgnustep-gui -lgnustep-base -lstdc++ -lm

resoundio_TOOL_LIBS = -lSndKit -lMKPerformSndMIDI \
                      -lgnustep-gui -lgnustep-base -lstdc++ -lm

resoundnib_TOOL_LIBS = -lSndKit -lMKPerformSndMIDI \
                       -lgnustep-gui -lgnustep-base -lstdc++ -lm

resoundmodule_TOOL_LIBS = -lSndKit -lMKPerformSndMIDI \
                          -lgnustep-gui -lgnustep-base -lstdc++ -lm

include $(GNUSTEP_MAKEFILES)/tool.make
