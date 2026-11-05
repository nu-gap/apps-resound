# Tests for the SndKit integration and the Resound file-I/O port.
#
# Builds:
#   - sndsmoke: exercises SndKit's libsndfile-backed file I/O
#     (load .wav -> write .au -> reload) without any audio device.
#   - resoundio: pins the intended behaviour of the Sound
#     (ResoundSound) category (Source/Sound-ResoundSound.m, compiled
#     into the tool) - the test-driven Phase 1 of the port (see
#     docs/RESOUND_SNDKIT_PLAN.md).
#
# Both run headless (no audio device, no display) and are fatal in CI.
#
# Prerequisite: the SndKit chain installed into the active GNUstep
# prefix (see ../third_party/build-sndkit.sh).

include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DOMAIN =	SYSTEM

TOOL_NAME = sndsmoke resoundio

sndsmoke_OBJC_FILES = sndsmoke.m

resoundio_OBJC_FILES = resoundio.m ../Source/Sound-ResoundSound.m

# The contract test compiles the category straight from the app tree;
# its header is needed for the quoted import in resoundio.m.
# (Global on purpose: gnustep-make strict v2 does not honour the
# per-product *_ADDITIONAL_INCLUDE_DIRS form.)
ADDITIONAL_INCLUDE_DIRS = -I../Source

sndsmoke_TOOL_LIBS = -lSndKit -lMKPerformSndMIDI \
                     -lgnustep-gui -lgnustep-base -lstdc++ -lm

resoundio_TOOL_LIBS = -lSndKit -lMKPerformSndMIDI \
                      -lgnustep-gui -lgnustep-base -lstdc++ -lm

include $(GNUSTEP_MAKEFILES)/tool.make
