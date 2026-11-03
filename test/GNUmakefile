# SndKit smoke test (see sndsmoke.m).
#
# Builds the sndsmoke tool, which exercises SndKit's libsndfile-backed
# file I/O (load .wav -> write .au -> reload) without any audio device,
# so it runs headless in CI.
#
# Prerequisite: the SndKit chain installed into the active GNUstep
# prefix (see ../build-sndkit.sh).

include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DOMAIN =	SYSTEM

TOOL_NAME = sndsmoke

sndsmoke_OBJC_FILES = sndsmoke.m

sndsmoke_TOOL_LIBS = -lSndKit -lMKPerformSndMIDI \
                     -lgnustep-gui -lgnustep-base -lstdc++ -lm

include $(GNUSTEP_MAKEFILES)/tool.make
