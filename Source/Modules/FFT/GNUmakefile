#
# GNUstep build system for the FFT module (Phase 3, eighth unit).
#
# The GNUstep twin of the 1998 Project Builder makefile next door
# (Loadable Bundle, bundle.make, BUNDLE_EXTENSION=rmod): a
# gnustep-make bundle producing FFT.rmod, which the app's
# ModuleController loadModules loads at runtime.  The 1998
# Makefile/PB.project pair is kept for reference only.  See
# docs/GNUSTEP_BUILD.md (modules) and docs/adrs/0020 for the
# decisions behind this recipe.
#
# Build:   make -f GNUmakefile          (builds FFT.rmod in-tree)
# Install: make -f GNUmakefile install  (into $(GNUSTEP_LIBRARY)/Resound,
#          where the app searches: <prefix>/lib/GNUstep/Resound for the
#          SYSTEM domain, ~/GNUstep/Library/Resound for the USER domain)
#
include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DOMAIN =	SYSTEM

BUNDLE_NAME =			FFT
BUNDLE_EXTENSION =		.rmod

# The class the app instantiates from the bundle (ModuleController
# loadAModule: uses NSBundle principalClass).  The 1998 Info file
# carried no NSPrincipalClass and relied on the NeXT runtime; the
# GNUstep NSBundle resolves the principal class from the key, so it
# is named explicitly (it lands in the generated Info-gnustep.plist).
FFT_PRINCIPAL_CLASS =		FFTModule

# The 1998 Makefile's CLASSES (all three module classes; the 1998
# bundle deliberately did NOT carry the app's ModuleSound category
# sources - the Snd(ModuleSound) methods the controller calls come
# from the app, which the module always runs inside).
FFT_OBJC_FILES =		FFTModule.m \
				FFTController.m \
				DiscreteGraphView.m

# The .m imports the app's ResoundNibs.h (the nib-era panel load call)
# from two levels up; the module's own headers resolve locally, as in
# 1998.  (Global on purpose: gnustep-make strict v2 does not honour
# the per-product *_ADDITIONAL_INCLUDE_DIRS form - test/GNUmakefile
# documents the same finding.)
ADDITIONAL_INCLUDE_DIRS =	-I../../

# The 1998 Makefile's GLOBAL_RESOURCES, the nib-era pair included:
# the module help text (the app's ModuleController looks it up in the
# bundle as ModuleInfo.rtfd), the control panel (the 1998 bundle
# carried FFT.nib at the bundle root - no lproj, so the root
# placement is the faithful one, as with the other nib'd modules;
# the bundle carries the gormtool twin, the directory resource,
# which is copied recursively to the bundle's top-level Resources)
# and the crosshair cursor image, which DiscreteGraphView loads from
# the bundle at init (pathForImageResource:@"FFTCursor") - unlike
# the Filter's FourSounds.tiff, a reference the code actually uses.
# The 1998 FFT.nib folder stays in the tree as the migration source,
# uninstalled.
FFT_RESOURCE_FILES =		ModuleInfo.rtfd \
				FFT.gorm \
				FFTCursor.tiff

# The module's C half (SndKit's Snd, plus the AppKit PS* drawing
# calls and the panel/buttons) resolves against libraries the app
# links anyway; the bundle declares them of its own accord (the Linux
# bundle link line uses $(BUNDLE_LIBS), not the app-style
# $(INSTANCE)_OBJC_LIBS).  The same set the test tool links
# (test/GNUmakefile).
FFT_BUNDLE_LIBS =		-lSndKit -lMKPerformSndMIDI \
				-lgnustep-gui -lgnustep-base \
				-lstdc++ -lm

# Where 'make install' puts the bundle: the app's ModuleController
# search path is every library domain + /Resound, plus the app bundle.
FFT_INSTALL_DIR =		$(GNUSTEP_LIBRARY)/Resound

include $(GNUSTEP_MAKEFILES)/bundle.make
