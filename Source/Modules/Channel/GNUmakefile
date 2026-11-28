#
# GNUstep build system for the Channel module (Phase 3, tenth unit).
#
# The GNUstep twin of the 1998 Project Builder makefile next door
# (Loadable Bundle, bundle.make, BUNDLE_EXTENSION=rmod): a
# gnustep-make bundle producing Channel.rmod, which the app's
# ModuleController loadModules loads at runtime.  The 1998
# Makefile/PB.project pair is kept for reference only.  See
# docs/GNUSTEP_BUILD.md (modules) and docs/adrs/0020 for the
# decisions behind this recipe.
#
# Build:   make -f GNUmakefile          (builds Channel.rmod in-tree)
# Install: make -f GNUmakefile install  (into $(GNUSTEP_LIBRARY)/Resound,
#          where the app searches: <prefix>/lib/GNUstep/Resound for the
#          SYSTEM domain, ~/GNUstep/Library/Resound for the USER domain)
#
include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DOMAIN =	SYSTEM

BUNDLE_NAME =			Channel
BUNDLE_EXTENSION =		.rmod

# The class the app instantiates from the bundle (ModuleController
# loadAModule: uses NSBundle principalClass).  The 1998 Info file
# carried no NSPrincipalClass and relied on the NeXT runtime; the
# GNUstep NSBundle resolves the principal class from the key, so it
# is named explicitly (it lands in the generated Info-gnustep.plist).
Channel_PRINCIPAL_CLASS =	ChannelModule

Channel_OBJC_FILES =		ChannelModule.m

# The module help text: the app's ModuleController looks it up in the
# bundle as ModuleInfo.rtfd (pathForResource:ofType:).  Channel is
# the family's second module without a control panel (after Zero) -
# the 1998 GLOBAL_RESOURCES pair is the rtfd and nothing else (no
# nib, no cursor).
Channel_RESOURCE_FILES =	ModuleInfo.rtfd

# The module's C half (SndLinearToMuLaw) plus the AppKit alert call
# resolve against libraries the app links anyway; the bundle declares
# them of its own accord (the Linux bundle link line uses
# $(BUNDLE_LIBS), not the app-style $(INSTANCE)_OBJC_LIBS).  The same
# set the test tool links (test/GNUmakefile).
Channel_BUNDLE_LIBS =		-lSndKit -lMKPerformSndMIDI \
				-lgnustep-gui -lgnustep-base \
				-lstdc++ -lm

# Where 'make install' puts the bundle: the app's ModuleController
# search path is every library domain + /Resound, plus the app bundle.
Channel_INSTALL_DIR =		$(GNUSTEP_LIBRARY)/Resound

include $(GNUSTEP_MAKEFILES)/bundle.make
