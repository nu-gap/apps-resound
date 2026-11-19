#
# GNUstep build system for the EchoChamber module (Phase 3, fourth unit).
#
# The GNUstep twin of the 1998 Project Builder makefile next door
# (Loadable Bundle, bundle.make, BUNDLE_EXTENSION=rmod): a
# gnustep-make bundle producing EchoChamber.rmod, which the app's
# ModuleController loadModules loads at runtime.  The 1998
# Makefile/PB.project pair is kept for reference only.  See
# docs/GNUSTEP_BUILD.md (modules) and docs/adrs/0020 for the
# decisions behind this recipe.
#
# Build:   make -f GNUmakefile          (builds EchoChamber.rmod in-tree)
# Install: make -f GNUmakefile install  (into $(GNUSTEP_LIBRARY)/Resound,
#          where the app searches: <prefix>/lib/GNUstep/Resound for the
#          SYSTEM domain, ~/GNUstep/Library/Resound for the USER domain)
#
include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DOMAIN =	SYSTEM

BUNDLE_NAME =			EchoChamber
BUNDLE_EXTENSION =		.rmod

# The class the app instantiates from the bundle (ModuleController
# loadAModule: uses NSBundle principalClass).  The 1998 Info file
# carried no NSPrincipalClass and relied on the NeXT runtime; the
# GNUstep NSBundle resolves the principal class from the key, so it
# is named explicitly (it lands in the generated Info-gnustep.plist).
# Note the 1998 class name is EchoChamber, not the XxxModule pattern
# of the other nine modules.
EchoChamber_PRINCIPAL_CLASS =	EchoChamber

EchoChamber_OBJC_FILES =		EchoChamber.m

# The .m imports the app's ResoundNibs.h (the nib-era panel load call)
# from two levels up; the module's own headers resolve locally, as in
# 1998.  (Global on purpose: gnustep-make strict v2 does not honour
# the per-product *_ADDITIONAL_INCLUDE_DIRS form - test/GNUmakefile
# documents the same finding.)
ADDITIONAL_INCLUDE_DIRS =	-I../../

# The module help text: the app's ModuleController looks it up in the
# bundle as ModuleInfo.rtfd (pathForResource:ofType:).
#
# And the module's control panel: the 1998 bundle carried it as
# EchoChamber.nib at the bundle root (no lproj - even less localized
# than Envelope's English.lproj), and the 1998 load was the
# +[NSBundle loadNibNamed:owner:] class method, which GNUstep
# implements in libs-gui's NSBundleAdditions.m as: resolve the name
# against the OWNING class's bundle first - the module bundle - and
# only then against the main app bundle; the path lookup
# (pathForResource:ofType:) searches the non-localized resource root
# first, so the root placement is the faithful one.  The 1998
# EchoChamber.nib folder stays in the tree as the migration source,
# uninstalled; the bundle carries the gormtool twin (the directory
# resource is copied recursively, landing at the bundle's top-level
# Resources).
EchoChamber_RESOURCE_FILES =	ModuleInfo.rtfd \
				EchoChamber.gorm

# The module's C half (SndKit's Snd/SndView, plus the AppKit alert
# call) resolves against libraries the app links anyway; the bundle
# declares them of its own accord (the Linux bundle link line uses
# $(BUNDLE_LIBS), not the app-style $(INSTANCE)_OBJC_LIBS).  The same
# set the test tool links (test/GNUmakefile).
EchoChamber_BUNDLE_LIBS =	-lSndKit -lMKPerformSndMIDI \
				-lgnustep-gui -lgnustep-base \
				-lstdc++ -lm

# Where 'make install' puts the bundle: the app's ModuleController
# search path is every library domain + /Resound, plus the app bundle.
EchoChamber_INSTALL_DIR =	$(GNUSTEP_LIBRARY)/Resound

include $(GNUSTEP_MAKEFILES)/bundle.make
