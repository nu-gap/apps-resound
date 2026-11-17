/*
resoundmodule
For the GNUstep port of Resound (gnustep-port branch)

The Phase 3 load contract for the Zero module, the first unit ported
from the module tree (see docs/GNUSTEP_BUILD.md).

What it does (headless: no display, no audio device):

  1. Loads the built Zero.rmod bundle through NSBundle and checks the
     principal class: it must be ZeroModule.  The app's
     ModuleController loadAModule: does exactly this - the bundle's
     generated Info-gnustep.plist carries NSPrincipalClass, and the
     principal class is the class the app instantiates.

  2. Instantiates the module (the same alloc/init the app runs) and
     checks the menu tree the 1998 init builds: exactly one leaf,
     named "Zero", targeting zeroSound: on the module itself - what
     the app's "Modules" menu shows after the load.

  3. Drives zeroSound: on a real in-memory Snd (the five 1998 data
     formats, mono and stereo) through a duck-typed controller/view,
     and checks that the whole selection is exactly zeroed - for mu-law
     to the 0xFF silence byte - and that stop / soundTouched reached the
     controller.  That is the module's DSP core, end to end.

The controller is injected by setting the module's private
moduleController ivar directly (object_setIvar): the app's own wiring
goes through setModuleControllerTo:, whose protocol-conformance check
a duck-typed double does not pass; the zeroSound: contract under test
is the same either way (the module only reads the ivar).

Usage:  resoundmodule <path-to-Zero.rmod>
(without an argument it looks for the in-tree build output)

Exit status: 0 when every check passes, 1 otherwise.
*/

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <SndKit/SndKit.h>
#import <objc/runtime.h>

#import "../Source/Modules/Zero/ZeroModule.h"

static int failures = 0;

/* The five data formats the 1998 module handles (its switch cases). */
static int zeroFormats[] = {
    SND_FORMAT_MULAW_8,
    SND_FORMAT_LINEAR_8,
    SND_FORMAT_LINEAR_16,
    SND_FORMAT_FLOAT,
    SND_FORMAT_DOUBLE
};

static void check (BOOL ok, const char *what)
{
    if (ok)
        printf ("ok   %s\n", what);
    else
    {
        printf ("FAIL %s\n", what);
        failures++;
    }
}

/*
A stand-in for the app's current sound view: it reports the whole sound
as the selection, which makes zeroSound: work on the entire buffer.
*/
@interface FakeSoundView : NSObject
{
    Snd *_sound;
}
- initWithSound: (Snd *)sound;
- (void) getSelection: (unsigned int *)firstSample size: (unsigned int *)sampleLength;
- (void) checkForCurrentDataOnPasteboard;
@end

@implementation FakeSoundView
- initWithSound: (Snd *)sound
    {
    if (self = [super init])
        _sound = [sound retain];
    return self;
    }
- (void) dealloc
    {
    [_sound release];
    [super dealloc];
    }
- (void) getSelection: (unsigned int *)firstSample size: (unsigned int *)sampleLength
    {
    *firstSample = 0;
    *sampleLength = (unsigned int)[_sound lengthInSampleFrames];
    }
- (void) checkForCurrentDataOnPasteboard
    {
    /* The app's ModuleSoundView category clears a stale pasteboard; a no-op here. */
    }
@end

/*
A stand-in for the app's ModuleController: it answers the four
ModuleProtocol methods zeroSound: uses and records the two side effects.
*/
@interface FakeModuleController : NSObject
{
    Snd *_sound;
    id _soundView;
    BOOL _stopped;
    BOOL _touched;
}
- initWithSound: (Snd *)sound soundView: (id)soundView;
- (id) currentSound;
- (id) currentSoundView;
- (void) stop;
- (void) soundTouched;
- (BOOL) wasStopped;
- (BOOL) wasTouched;
@end

@implementation FakeModuleController
- initWithSound: (Snd *)sound soundView: (id)soundView
    {
    if (self = [super init])
    {
        _sound = [sound retain];
        _soundView = [soundView retain];
        _stopped = NO;
        _touched = NO;
    }
    return self;
    }
- (void) dealloc
    {
    [_sound release];
    [_soundView release];
    [super dealloc];
    }
- (id) currentSound
    {
    return _sound;
    }
- (id) currentSoundView
    {
    return _soundView;
    }
- (void) stop
    {
    _stopped = YES;
    }
- (void) soundTouched
    {
    _touched = YES;
    }
- (BOOL) wasStopped
    {
    return _stopped;
    }
- (BOOL) wasTouched
    {
    return _touched;
    }
@end

/* Fill the sound's buffer with a non-silence pattern. */
static void fill (Snd *snd, char pattern)
{
    void *bytes = [snd bytes];
    long size = [snd dataSize];
    int x;
    for (x = 0; x < size; x++)
        ((char *)bytes)[x] = pattern;
}

/* Every byte of the buffer must equal the expected silence byte. */
static BOOL allSilent (Snd *snd, char expected)
{
    void *bytes = [snd bytes];
    long size = [snd dataSize];
    int x;
    for (x = 0; x < size; x++)
        if (((char *)bytes)[x] != expected)
            return NO;
    return YES;
}

static void testZeroing (id module, SndSampleFormat fmt, int channels)
{
    const char *name = [SndFormatName (fmt, NO) cStringUsingEncoding: NSASCIIStringEncoding];

    printf ("== zeroSound: %s, %d channel(s)\n", name, channels);
    long frames = 97;
    Snd *snd;
    FakeSoundView *view;
    FakeModuleController *controller;
    Ivar ivar;

    snd = [[[Snd alloc] initWithFormat: fmt
                           channelCount: channels
                               frames: (unsigned long)frames
                         samplingRate: 44100.0f] autorelease];
    if (snd == nil)
    {
        check (NO, "Snd construction");
        return;
    }
    check ([snd lengthInSampleFrames] == (unsigned long)frames
       && [snd channelCount] == channels
       && [snd dataFormat] == fmt, "Snd format");

    fill (snd, 0xA5);

    view = [[[FakeSoundView alloc] initWithSound: snd] autorelease];
    controller = [[[FakeModuleController alloc] initWithSound: snd soundView: view] autorelease];

    /* Inject the controller the way the app's wiring would have the
       ivar end up; the conformance-checked setter is the app's path. */
    ivar = class_getInstanceVariable ([module class], "moduleController");
    check (ivar != NULL, "moduleController ivar");
    object_setIvar (module, ivar, controller);

    [(ZeroModule *)module zeroSound: nil];

    check ([controller wasStopped], "zeroSound: stopped playback first");
    check ([controller wasTouched], "zeroSound: reported the sound touched");

    if (fmt == SND_FORMAT_MULAW_8)
        /* No message brackets: this is a C function (or a macro with
           FAST_ULAW_CONVERSION), not an Objective-C message.  0xFF is
           the G.711 mu-law code for zero; the 1998 comment guessed
           127, which is a small DC offset, not silence - the SndKit
           conversion is the standard one. */
        check (SndLinearToMuLaw (0) == 0xFF, "mu-law silence byte is 0xFF");
    check (allSilent (snd, fmt == SND_FORMAT_MULAW_8
                                   ? (char)SndLinearToMuLaw (0)
                                   : 0),
           fmt == SND_FORMAT_MULAW_8 ? "buffer zeroed (mu-law 0xFF)" : "buffer zeroed");
}

int main (int argc, char **argv)
{
    NSString *rmod = argc > 1
        ? [NSString stringWithUTF8String: argv[1]]
        : @"../Source/Modules/Zero/Zero.rmod";
    NSBundle *bundle;
    Class principal;
    id module;
    id root, leaf;
    Ivar ivar;
    int c;

    printf ("resoundmodule: %s\n", [rmod UTF8String]);

    bundle = [[NSBundle alloc] initWithPath: rmod];
    check (bundle != nil, "NSBundle initWithPath");
    if (bundle == nil)
        return 1;

    /* 1. The principal class. */
    principal = [bundle principalClass];
    check (principal != Nil, "principalClass is loaded");
    check (principal != Nil && [NSStringFromClass (principal) isEqualToString: @"ZeroModule"],
           "principal class is ZeroModule");
    if (principal == Nil)
        return 1;

    /* 2. The menu tree the app's Modules menu is built from. */
    module = [[principal alloc] init];
    check (module != nil, "module instantiation");
    root = [module getModuleMenuNode];
    check (root != nil, "root menu node");
    check (root != nil && [root numSubmenus] == 1, "root has exactly one submenu");
    leaf = root != nil ? [root getSubmenu: 0] : nil;
    check (leaf != nil && [leaf isLeafNode], "leaf node");
    check (leaf != nil && [[leaf getNameAsString] isEqualToString: @"Zero"], "leaf is named Zero");
    check (leaf != nil && [NSStringFromSelector ([leaf getMessage]) isEqualToString: @"zeroSound:"],
           "leaf targets zeroSound:");
    check (leaf != nil && [leaf getReceiver] == module, "leaf targets the module");

    /* 3. The DSP core: the five 1998 formats, mono and stereo. */
    ivar = class_getInstanceVariable ([module class], "moduleController");
    check (ivar != NULL, "moduleController ivar (for the DSP cases)");

    for (c = 0; c < 5; c++)
        testZeroing (module, (SndSampleFormat)zeroFormats[c], 1);
    for (c = 0; c < 5; c++)
        testZeroing (module, (SndSampleFormat)zeroFormats[c], 2);

    if (failures == 0)
        printf ("resoundmodule: all checks passed\n");
    else
        printf ("resoundmodule: %d check(s) failed\n", failures);
    return failures == 0 ? 0 : 1;
}
