# Tests for the SndKit integration, the Resound file-I/O port and the
# converted NIB assets.
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
#
# sndsmoke and resoundio run headless (no audio device, no display)
# and are fatal in CI.
#
# Prerequisite: the SndKit chain installed into the active GNUstep
# prefix (see ../third_party/build-sndkit.sh).

# Build the tool instances serially.
#
# gnustep-make (strict v2) runs one sub-make per tool, in parallel.
# Two of the tools below compile sources from the shared ../Source
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

TOOL_NAME = sndsmoke resoundio resoundnib

sndsmoke_OBJC_FILES = sndsmoke.m

resoundio_OBJC_FILES = resoundio.m ../Source/Sound-ResoundSound.m

# The NIB tests compile the ported app sources the way the app does
# (minus Resound_main.m, whose NSApplicationMain the test replaces):
# that is what makes the console fully loadable under --load, since
# the console is the only unit whose classes are ported so far.
resoundnib_OBJC_FILES = resoundnib.m \
	../Source/ResoundNibs.m \
	../Source/Extra.m \
	../Source/ModuleMenuNode.m \
	../Source/Sound-ResoundSound.m \
	../Source/SoundManager.m \
	../Source/MiscVolumeMeter.m \
	../Source/ResoundMiscVolumeMeter.m \
	../Source/MiscSoundTracker.m \
	../Source/ConsoleManager.m

resoundnib_C_FILES = ../Source/fft.c

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

include $(GNUSTEP_MAKEFILES)/tool.make
