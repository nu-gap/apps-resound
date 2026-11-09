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

# The main nib (NSMainNibFile) is left unset for now: the Resound.nib
# conversion to .gorm is done (see below and docs/RESOUND_SNDKIT_PLAN.md,
# NIB migration section), but loading it would instantiate the
# FileController, which is still blocked.  Once the FileController unit
# lands, set:
#   Resound_MAIN_MODEL_FILE = Resound
#
# Resource files (added step by step as they are migrated).
#
# Note: ResoundInfo.plist (next to this GNUmakefile) is a build-time
# input only - it is merged into the generated Info-gnustep.plist and
# is intentionally not copied into the bundle.
#
# The 1998 .nib files cannot be loaded by the GNUstep runtime, so the
# bundle carries the converted .gorm folders (produced with gormtool,
# gnustep/apps-gorm branch OPENSTEP_nib_support) - one per .nib, sitting
# side by side with the originals, which stay in the tree as the
# migration source.  Call sites use the logical name (no extension);
# Source/ResoundNibs.{h,m} resolves it per platform (a native build
# would bundle the .nib folders from this very list instead).
# gnustep-make copies directory resources recursively.
Resound_RESOURCE_FILES= \
	Resound.tiff \
	AttributesInspector.gorm \
	Console.gorm \
	Edit.gorm \
	error.gorm \
	File.gorm \
	InfoStringInspector.gorm \
	Inspector.gorm \
	MarksInspector.gorm \
	Module.gorm \
	Preferences.gorm \
	Resound.gorm \
	SelectionInspector.gorm \
	Volume.gorm \
	ZoomInspector.gorm

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
	Source/SoundDocumentTable.m \
	Source/SoundManager.m \
	Source/MiscVolumeMeter.m \
	Source/ResoundMiscVolumeMeter.m \
	Source/MiscSoundTracker.m \
	Source/ConsoleManager.m \
	Source/MiscSoundView.m \
	Source/MiscSoundViewRuler.m \
	Source/ResoundMiscSoundView.m \
	Source/ResoundNibs.m

Resound_C_FILES= \
	Source/fft.c

# BLOCKED by SoundKit (needs the SndKit migration, see
# docs/RESOUND_SNDKIT_PLAN.md phases 1-3): AttributesInspector,
# EditController, FileController, InfoStringInspector, InspectorManager,
# MarksInspector, Module, ModuleController, ModuleSound, ModuleSoundView,
# PreferencesManager, ResoundScrollView, SelectionInspector, VolumeController,
# ZoomInspector

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/application.make

-include GNUmakefile.postamble
