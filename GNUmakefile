#
# GNUstep build system for Resound (gnustep-make compatible).
#
# This is the bootstrap of the GNUstep build system.  Source files are
# added to Resound_OBJC_FILES / Resound_C_FILES step by step as they
# are ported from the Rhapsody/OpenStep code to GNUstep.  See
# docs/GNUSTEP_BUILD.md for the conventions and the current status of
# the file-by-file port.
#
# Build:
#   make -f GNUmakefile            (builds obj/Resound.app)
#   make -f GNUmakefile install    (installs into the SYSTEM domain, /System)
#
#
# The build is in-tree (the GNUstep makefiles of this Gershwin system
# expect the default build dir "."): the Resound.app bundle is created
# in the source tree, next to the source files.  The legacy resource
# files live in Resources/ (the canonical GNUstep app layout); the
# Resound.app directory itself is the in-tree build bundle.
#
include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DOMAIN =	SYSTEM

APP_NAME=			Resound
PACKAGE_NAME=		Resound

# The custom Info.plist (merged into the generated Info-gnustep.plist
# via plmerge).  It must be named ResoundInfo.plist next to this
# GNUmakefile to be picked up automatically.
#
# On platforms where Foundation/AppKit ship as frameworks (e.g. a
# future macOS target) add:
#   Resound_FRAMEWORKS = -framework AppKit -framework Foundation
# On the GNUstep platform the gui+base shared libraries are linked
# automatically (NEEDS_GUI).

# Base directory of the resource files (nibs, icons, ...).
Resound_RESOURCE_FILES_DIR =	Resources

Resound_PRINCIPAL_CLASS=	NSApplication
Resound_APPLICATION_ICON=	Resound.tiff

# The main nib (NSMainNibFile) is left unset for now: the legacy
# NeXT-format .nib files need to be migrated to GNUstep-format nibs
# first (see docs/RESOUND_SNDKIT_PLAN.md, NIB migration section).
# Once the Resound.nib conversion is done, set:
#   Resound_MAIN_MODEL_FILE = Resound

#
# Resource files (added step by step as they are migrated).
#
# Note: ResoundInfo.plist (next to this GNUmakefile) is a build-time
# input only - it is merged into the generated Info-gnustep.plist and
# is intentionally not copied into the bundle.
#
Resound_RESOURCE_FILES= \
	Resound.tiff

#
# Sources (added step by step as they are ported to GNUstep)
#
# Classification of the original app sources against the GNUstep
# toolchain (Gershwin /System) - see docs/GNUSTEP_BUILD.md for details.
#
# SndKit and its portaudio performance backend, from the pinned
# third_party/MusicKit submodule (see docs/GNUSTEP_BUILD.md, SndKit).
# Needed by the file-I/O category (Source/Sound-ResoundSound.m) and,
# as the migration progresses, by everything that touches sound objects.
# (Strict v2: per-product libraries for an app's ObjC code go into
# $(INSTANCE)_OBJC_LIBS, which feeds ADDITIONAL_OBJC_LIBS and hence
# the app link line; $(INSTANCE)_LIBS is for library products.)
Resound_OBJC_LIBS = -lSndKit -lMKPerformSndMIDI -lstdc++ -lm

# READY (compiles and links against the GNUstep toolchain):
Resound_OBJC_FILES= \
	Source/Resound_main.m \
	Source/Extra.m \
	Source/ModuleMenuNode.m \
	Source/Sound-ResoundSound.m \
	Source/SoundManager.m

Resound_C_FILES= \
	Source/fft.c

# BLOCKED by SoundKit (needs the SndKit migration, see
# docs/RESOUND_SNDKIT_PLAN.md phases 1-3): AttributesInspector,
# ConsoleManager, EditController, FileController, InfoStringInspector,
# InspectorManager, MarksInspector, MiscSoundTracker, MiscSoundView,
# MiscSoundViewRuler, MiscVolumeMeter, Module, ModuleController,
# ModuleSound, ModuleSoundView, PreferencesManager, ResoundMiscSoundView,
# ResoundMiscVolumeMeter, ResoundScrollView, SelectionInspector,
# SoundDocumentTable, VolumeController, ZoomInspector

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/application.make

-include GNUmakefile.postamble
