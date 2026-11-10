/*
 ResoundMissingClasses
 The GNUstep port (see docs/RESOUND_SNDKIT_PLAN.md): placeholder
 classes for the classes the converted 1998 main model (Resound.gorm,
 the NSMainNibFile) references that are not linked into the app yet.

 The 1998 main nib instantiates the FileController, the ConsoleManager
 and the SoundManager (all ported), plus the PreferencesManager, the
 EditController, the InspectorManager, the five inspectors
 (InfoString/Attributes/Marks/Selection/Zoom), the VolumeController
 and the ModuleController(+Instance) objects (all blocked on their
 units).  The 1998 Rhapsody nib loader skipped unknown classes: the
 object came up nil, the rest of the model loaded, and the 1998 code
 nil-guards every use.  The GNUstep gorm loader is strict: a class it
 cannot resolve raises and the whole main model fails to load
 (verified: "Unable to find class 'InfoStringInspector'" at first
 launch with NSMainNibFile set).

 These stubs reproduce the 1998 semantics under GNUstep: each blocked
 class name resolves to an inert object, so the main model loads and
 the app comes up with its 1998 main window.  Every send the live
 (ported) code or the 1998 nib wiring makes to a stubbed object is
 swallowed by the resolver below and returns zero - the 1998 code's
 own nil-guards were written for exactly this (a nil object answers
 zero to everything), so the behaviour matches the 1998 no-classes
 variant instead of crashing.  Inherited NSObject behaviour
 (retain/release/dealloc, isKindOfClass:, ...) is untouched: the
 resolver only answers selectors the runtime cannot find.

 The stubs are the nib-level form of the port's standing bridges
 (the id-bridges and protocol bridges the other units use until a
 neighbour lands).  Each stub is deleted with the unit that ports its
 real class - never keep a stub and its real class in the build at
 the same time.  FileController.m imports three of the 1998 stubbed
 headers (EditController/PreferencesManager/InspectorManager); that
 is harmless: an @interface re-declaration with the same NSObject
 superclass is legal, and the real class is emitted only here.
*/

#import <Foundation/Foundation.h>

/* The swallow: x0 = 0 reads as nil / NO / 0 / 0.0 for every return
   type, so one IMP serves all.  (Verified on the gnustep-2.2 runtime
   by probe: object returns nil, a BOOL-typed read of the same send
   sees 0, inherited methods are not swallowed.) */
static id ResoundStubSwallow(id self, SEL _cmd)
{
    return nil;
}

/* Register a swallow for any selector the class does not otherwise
   respond to.  Returns NO for selectors the class already implements,
   so normal (inherited) behaviour wins. */
static BOOL ResoundStubResolve(Class theClass, SEL sel)
{
    if (class_getInstanceMethod(theClass, sel))
	return NO;
    class_addMethod(theClass, sel, (IMP) ResoundStubSwallow, "@@:");
    return YES;
}

/* ------------------------------------------------------------------ */

/* Retired with the preferences unit (Phase 2). */
@interface PreferencesManager : NSObject
@end
@implementation PreferencesManager
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end

/* Retired with the edit unit (Phase 2). */
@interface EditController : NSObject
@end
@implementation EditController
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end

/* Retired with the inspector-manager unit (Phase 2). */
@interface InspectorManager : NSObject
@end
@implementation InspectorManager
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end

/* Retired with the info-string-inspector unit (Phase 2). */
@interface InfoStringInspector : NSObject
@end
@implementation InfoStringInspector
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end

/* Retired with the attributes-inspector unit (Phase 2). */
@interface AttributesInspector : NSObject
@end
@implementation AttributesInspector
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end

/* Retired with the marks-inspector unit (Phase 2). */
@interface MarksInspector : NSObject
@end
@implementation MarksInspector
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end

/* Retired with the selection-inspector unit (Phase 2). */
@interface SelectionInspector : NSObject
@end
@implementation SelectionInspector
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end

/* Retired with the volume unit (Phase 2). */
@interface VolumeController : NSObject
@end
@implementation VolumeController
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end

/* Retired with the zoom-inspector unit (Phase 2). */
@interface ZoomInspector : NSObject
@end
@implementation ZoomInspector
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end

/* Retired with the module unit (Phase 3).  The 1998 ModuleController.h
   (a different @interface for the same name) is guarded out of every
   built TU by NOT_COMPILING_WITH_MODULES, so it never meets this stub
   in a translation unit; the two retire together. */
@interface ModuleController : NSObject
@end
@implementation ModuleController
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end

/* Retired with the module unit (Phase 3).  A nib-internal 1998 class
   with no source file in the tree (it appears only in Resound.nib /
   Resound.gorm); the stub stands in for it. */
@interface ModuleControllerInstance : NSObject
@end
@implementation ModuleControllerInstance
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end

/* The 1998 FileType.subproj error handler (Source/FileType.subproj,
   the defunct legacy file readers).  Its readers were dropped in
   Phase 1 (SndKit's libsndfile readers replaced them), which made the
   main model's ErrorHandler object a 1998 vestige; the stub keeps
   the model loadable.  There is no unit that will port the 1998
   ErrorHandler, so this stub stays until the main model is re-nibbed
   without it (the 1998 .nib / converted .gorm are kept as-is). */
@interface ErrorHandler : NSObject
@end
@implementation ErrorHandler
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end

/* The 1998 Inspector base class: nib-internal (no source file in the
   tree; the 1998 inspectors descend from it in the nib's class table).
   Stays until the inspector units land (Phase 2), with the inspector
   stubs above. */
@interface Inspector : NSObject
@end
@implementation Inspector
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end

/* Nib-internal 1998 instance wrappers (no source file in the tree);
   they appear only in the main model.  Retired with the owning unit
   (the preferences / audio-engine re-nib). */
@interface PreferencesManagerInstance : NSObject
@end
@implementation PreferencesManagerInstance
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end

@interface SoundManagerInstance : NSObject
@end
@implementation SoundManagerInstance
+ (BOOL) resolveInstanceMethod:(SEL) sel
{
    return ResoundStubResolve(self, sel);
}
@end
