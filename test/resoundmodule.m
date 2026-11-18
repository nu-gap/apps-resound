/*
resoundmodule
For the GNUstep port of Resound (gnustep-port branch)

The Phase 3 load contracts for the ported modules - so far the Zero
module (zeroSound:) and the Mix module (mix:) - the first two units
from the module tree (see docs/GNUSTEP_BUILD.md).

What it does (headless: no display, no audio device):

  1. Loads the built module bundle through NSBundle and checks the
     principal class.  The app's ModuleController loadAModule: does
     exactly this - the bundle's generated Info-gnustep.plist carries
     NSPrincipalClass, and the principal class is the class the app
     instantiates - so the test dispatches on the class name, exactly
     like the app: ZeroModule runs the zero contract, MixModule the
     mix contract.

  2. Instantiates the module (the same alloc/init the app runs) and
     checks the menu tree the 1998 init builds: exactly one leaf -
     named "Zero" targeting zeroSound:, or "Mix In" targeting mix:,
     on the module itself - what the app's "Modules" menu shows
     after the load.

  3. Drives the module's DSP on real in-memory Snds, mono and stereo,
     over the five 1998 data formats, through a duck-typed
     controller:
       - zeroSound: on a whole-sound selection, the buffer checked
         to be exactly zeroed - for mu-law to the 0xFF silence byte -
         and stop / soundTouched reaching the controller;
       - mix: with the pasteboard the way the 1998 flow uses it: an
         empty pasteboard is a no-op (document untouched), and a
         source selection on the pasteboard is added into the
         document selection in the document's own format, the
         expected values computed through SndKit's own conversion
         calls so the expectation mirrors the port exactly.

The controller is injected by setting the module's private
moduleController ivar directly (object_setIvar): the app's own wiring
goes through setModuleControllerTo:, whose protocol-conformance check
a duck-typed double does not pass; the contract under test is the
same either way (the module only reads the ivar).

The mix: controller double answers the 1998 newWindow call with the
selector the app's ModuleController actually carries: the 1998
no-space declaration demotes its parameter names (the
-Wmissing-selector-name warnings the app build already carries), so
the method's selector is newWindow::: - the same selector the 1998
unlabeled module call generates.  The double reproduces that exact
declaration shape (and its two warnings, on purpose).

Usage:  resoundmodule <path-to-rmod>
(without an argument it looks for the in-tree Zero build output)

Exit status: 0 when every check passes, 1 otherwise.
*/

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <SndKit/SndKit.h>
#import <objc/runtime.h>

/* The app's copy of the module base classes, the same files the tool
   compiles in below (../Source/Module.m) - one path for the shared
   headers, so #import dedupes them. */
#import "../Source/Module.h"

/* Minimal local mirrors of the two module headers, instead of the
   module directories' copies: those import the module-directory
   copies of the base headers (a second path for the same classes),
   which #import would reject as duplicate interface definitions once
   the app's ../Source copies are in.  The gate only needs the class
   names and the selectors it drives; the bundles under test supply
   the implementations (and their real headers stay next to them,
   where the bundles' own builds use them). */
@interface ZeroModule : Module
- init;
- zeroSound:sender;
@end

@interface MixModule : Module
- init;
- mix:sender;
@end

static int failures = 0;

/* The five data formats the 1998 modules' DSP switches handle. */
static int dspFormats[] = {
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

/*
A stand-in for the app's ModuleController for the mix: contract: it
answers currentSoundView with the real document view, the 1998
newWindow call with a bare SndView (the throw-away paste vehicle the
1998 flow builds), and records soundChanged.

The newWindow declaration deliberately keeps the 1998 no-space shape
(type right after the colon, the name before the next colon): the
app's ModuleController.m carries exactly that shape, and clang demotes
its parameter names to names (the -Wmissing-selector-name warnings the
app build already emits for it), so the app's method - and this
double's - has the selector newWindow:::.  That is the selector the
1998 unlabeled module call generates, so the double must match it; the
two warnings this declaration costs in this build are the 1998
fingerprint, on purpose.
*/
@interface FakeMixController : NSObject
{
    id _soundView;
    SndView *_tmpView;
    int _soundChanged;
}
- initWithSoundView: (id)soundView;
- (id) currentSoundView;
- (void)newWindow:(id *)theWindowPointer:(id *)theScrollViewPointer:(id *)theSoundViewPointer;
- (void) soundChanged;
- (int) soundChangedCount;
@end

@implementation FakeMixController
- initWithSoundView: (id)soundView
    {
    if (self = [super init])
    {
        _soundView = [soundView retain];
        _tmpView = nil;
        _soundChanged = 0;
    }
    return self;
    }
- (void) dealloc
    {
    [_soundView release];
    [_tmpView release];
    [super dealloc];
    }
- (id) currentSoundView
    {
    return _soundView;
    }
- (void)newWindow:(id *)theWindowPointer:(id *)theScrollViewPointer:(id *)theSoundViewPointer
    {
    /* The 1998 app's newWindow: builds a real window/scroll view/
       sound view; the module never touches the window and scroll
       view after the call, so the double supplies the one part the
       flow uses - a bare SndView - and nils for the rest. */
    *theWindowPointer = nil;
    *theScrollViewPointer = nil;
    if (_tmpView == nil)
        _tmpView = [[SndView alloc] initWithFrame: NSMakeRect (0, 0, 320, 200)];
    *theSoundViewPointer = _tmpView;
    }
- (void) soundChanged
    {
    _soundChanged++;
    }
- (int) soundChangedCount
    {
    return _soundChanged;
    }
@end

/*
Fill the sound's buffer with a non-silence pattern: a 16-bit linear
value per sample, narrowed per format.  The source and document
patterns are deliberately different, so the mix is not an identity.
The expectation below never recomputes the pattern - it reads both
sides back in the sound's own format - so whatever the narrowing does
(wrap for the int formats, the G.711 code for mu-law) cancels.
*/
static int pattern (int which, long sample, int channel)
{
    if (which == 0)
        return ((sample * 23 + channel * 7) % 1009) - 504;
    return ((sample * 31 + channel * 13) % 1009) - 504;
}

static void fillPattern (Snd *snd, int which)
{
    long frames = (long)[snd lengthInSampleFrames];
    int ch = [snd channelCount];
    void *bytes = [snd bytes];
    long n;
    for (n = 0; n < frames * ch; n++)
    {
        int v = pattern (which, n / ch, (int)(n % ch));
        switch ([snd dataFormat])
        {
        case SND_FORMAT_MULAW_8:
            ((unsigned char *)bytes)[n] = SndLinearToMuLaw ((short)v);
            break;
        case SND_FORMAT_LINEAR_8:
            ((char *)bytes)[n] = (char)v;
            break;
        case SND_FORMAT_LINEAR_16:
            ((short *)bytes)[n] = (short)v;
            break;
        case SND_FORMAT_FLOAT:
            ((float *)bytes)[n] = (float)v;
            break;
        case SND_FORMAT_DOUBLE:
            ((double *)bytes)[n] = (double)v;
            break;
        default:
            break;
        }
    }
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

/*
The 1998 Mix DSP, sample by sample: add src into dst over count
samples in the sound's own format - the same typed adds (mu-law via
the same table functions and clip the module calls), so the
expected document equals the module's arithmetic exactly.
*/
static void dspAdd (unsigned char *dst, const unsigned char *src,
                    long count, SndSampleFormat fmt)
{
    long x;
    switch (fmt)
    {
    case SND_FORMAT_MULAW_8:
        for (x = 0; x < count; x++)
        {
            int lin = SndMuLawToLinear (dst[x]) + SndMuLawToLinear (src[x]);
            LINCLIP (lin);
            dst[x] = SndLinearToMuLaw ((short)lin);
        }
        break;
    case SND_FORMAT_LINEAR_8:
        for (x = 0; x < count; x++)
            ((char *)dst)[x] += ((char *)src)[x];
        break;
    case SND_FORMAT_LINEAR_16:
        for (x = 0; x < count; x++)
            ((short *)dst)[x] += ((short *)src)[x];
        break;
    case SND_FORMAT_FLOAT:
        for (x = 0; x < count; x++)
            ((float *)dst)[x] += ((float *)src)[x];
        break;
    case SND_FORMAT_DOUBLE:
        for (x = 0; x < count; x++)
            ((double *)dst)[x] += ((double *)src)[x];
        break;
    default:
        break;
    }
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

    fillPattern (snd, 0);

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

/*
The mix: contract with an empty pasteboard: the 1998 flow reads the
pasteboard into a fresh sound, finds no sound type on it, and must
leave the document untouched (and report soundChanged, as the 1998
code does unconditionally after the read).  The emptiness comes from
the pasteboard server, not the process: GNUstep's NSPasteboard
client auto-launches a fresh gpbs when no pasteboard server is
running (the server then stops when the last client leaves), so a
CI job's first pasteboard user sees an empty board.  This case must
therefore run before the DSP cases below write selections to the
board - GNUstep's NSPasteboard offers no clearContents to reset it.
*/
static void testMixNoop (id module, Ivar ivar)
{
    printf ("== mix: with an empty pasteboard (the no-op path)\n");

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSArray *types = [NSArray arrayWithObject: SndPasteboardType];
    check (![pb availableTypeFromArray: types],
           "general pasteboard starts type-less");

    Snd *doc = [[[Snd alloc] initWithFormat: SND_FORMAT_LINEAR_16
                                channelCount: 1
                                    frames: 200
                              samplingRate: 44100.0f] autorelease];
    check (doc != nil, "document Snd");
    fillPattern (doc, 1);
    SndView *docView = [[[SndView alloc] initWithFrame: NSMakeRect (0, 0, 320, 200)] autorelease];
    [docView setSound: doc];
    [docView setSelection: 10 size: 50];

    long docSize = [doc dataSize];
    unsigned char *docBefore = malloc (docSize);
    memcpy (docBefore, [doc bytes], (size_t)docSize);

    FakeMixController *controller =
        [[[FakeMixController alloc] initWithSoundView: docView] autorelease];
    object_setIvar (module, ivar, controller);

    id ret = [(MixModule *)module mix: nil];

    check (ret == module, "mix: returns self");
    check ([controller soundChangedCount] == 1, "mix: reported the sound changed");
    check (memcmp ([doc bytes], docBefore, (size_t)docSize) == 0,
           "document untouched (nothing to mix in)");
    check (![pb availableTypeFromArray: types],
           "pasteboard still type-less after the no-op");
    free (docBefore);
}

/*
The mix: DSP contract: a source selection (srcLoc, srcLen) is put on
the general pasteboard the way a user copy does, then mixed into the
document selection (docLoc, docLen) of a 200-frame document.  The
expected document is the pre-mix document with the pasted selection
added in - the paste hopped through the two conversions the flow
performs (SndKit's own convertToSampleFormat: on a scratch copy, so
the expectation mirrors the port whatever its math does), and the add
is the 1998 per-format DSP.  Frames outside the clamped mix range must
stay untouched.
*/
static void testMix (id module, Ivar ivar, SndSampleFormat fmt, int ch,
                     int srcLoc, int srcLen, int docLoc, int docLen)
{
    const char *name = [SndFormatName (fmt, NO) cStringUsingEncoding: NSASCIIStringEncoding];
    printf ("== mix: %s, %d channel(s), source selection (%d,%d), document selection (%d,%d)\n",
            name, ch, srcLoc, srcLen, docLoc, docLen);

    /* The source, in a real SndView; the selection goes to the
       general pasteboard the way a user copy does. */
    Snd *src = [[[Snd alloc] initWithFormat: fmt
                               channelCount: ch
                                   frames: 120
                             samplingRate: 44100.0f] autorelease];
    check (src != nil && [src lengthInSampleFrames] == 120, "source Snd");
    fillPattern (src, 0);
    SndView *srcView = [[[SndView alloc] initWithFrame: NSMakeRect (0, 0, 320, 200)] autorelease];
    [srcView setSound: src];
    [srcView setSelection: srcLoc size: srcLen];

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    check ([srcView writeSelectionToPasteboard: pb
                                         types: [NSArray arrayWithObject: SndPasteboardType]],
           "source selection written to the pasteboard");
    check ([pb availableTypeFromArray: [NSArray arrayWithObject: SndPasteboardType]] != nil,
           "pasteboard offers the sound type");

    /* The document, in a real SndView with its selection. */
    Snd *doc = [[[Snd alloc] initWithFormat: fmt
                               channelCount: ch
                                   frames: 200
                             samplingRate: 44100.0f] autorelease];
    check (doc != nil, "document Snd");
    fillPattern (doc, 1);
    SndView *docView = [[[SndView alloc] initWithFrame: NSMakeRect (0, 0, 320, 200)] autorelease];
    [docView setSound: doc];
    [docView setSelection: docLoc size: docLen];

    long docSize = [doc dataSize];
    unsigned char *docBefore = malloc (docSize);
    memcpy (docBefore, [doc bytes], (size_t)docSize);

    FakeMixController *controller =
        [[[FakeMixController alloc] initWithSoundView: docView] autorelease];
    object_setIvar (module, ivar, controller);

    id ret = [(MixModule *)module mix: nil];

    check (ret == module, "mix: returns self");
    check ([controller soundChangedCount] == 1, "mix: reported the sound changed");
    check ([doc dataFormat] == fmt && [doc channelCount] == ch
       && [doc lengthInSampleFrames] == 200,
           "document still its own format and length");

    /* The pasted selection after the hops the paste path performs:
       the paste does not fit the fresh zero-frame FLOAT/stereo/
       44.1k vehicle, so SndKit converts it to the vehicle's format
       (Snd.m compatibleWithSound/convertToSampleFormat), and the
       module then converts it to the document's format.  Run the
       same calls on a scratch copy of the selection - whatever
       SndKit's conversion math does, the expectation matches it. */
    Snd *sel = [src soundFromSamplesInRange: NSMakeRange (srcLoc, srcLen)];
    check (sel != nil && [sel lengthInSampleFrames] == (unsigned long)srcLen,
           "pasted selection extracted from the source");
    [sel convertToSampleFormat: SND_FORMAT_FLOAT samplingRate: 44100.0 channelCount: 2];
    [sel convertToSampleFormat: fmt samplingRate: 44100.0 channelCount: ch];
    check ([sel dataFormat] == fmt && [sel channelCount] == ch
       && [sel lengthInSampleFrames] == (unsigned long)srcLen,
           "pasted selection hopped to the document format");

    /* The module clamps the mix size to the shorter of the selection
       and the pasted sound; its DSP runs over that many frames (times
       the channel count) of the document selection.  The module
       indexes in samples (its DSP pointers are typed per format), but
       a sound buffer is bytes - so the offsets below are the same
       sample counts times the bytes-per-sample of the document's
       format (1 for the 8-bit formats, 2/4/8 for the wide ones). */
    int addLen = (srcLen < docLen ? srcLen : docLen);
    int bps = (fmt == SND_FORMAT_LINEAR_16 ? 2
             : fmt == SND_FORMAT_FLOAT ? 4
             : fmt == SND_FORMAT_DOUBLE ? 8 : 1);
    long addSamples = (long)addLen * ch;
    long off = (long)docLoc * ch * bps;
    long addBytes = addSamples * bps;

    unsigned char *expected = malloc ((size_t)docSize);
    memcpy (expected, docBefore, (size_t)docSize);
    if (addSamples > 0)
        dspAdd (expected + off, (const unsigned char *)[sel bytes], addSamples, fmt);

    check (memcmp ([doc bytes] + off, expected + off, (size_t)addBytes) == 0,
           "mixed range matches the 1998 DSP arithmetic");
    check (memcmp ([doc bytes], expected, (size_t)docSize) == 0,
           "the rest of the document is untouched");
    free (docBefore);
    free (expected);
}

static void runZero (Class principal)
{
    /* The menu tree the app's Modules menu is built from. */
    id module = [[principal alloc] init];
    check (module != nil, "module instantiation");
    id root = [module getModuleMenuNode];
    check (root != nil, "root menu node");
    check (root != nil && [root numSubmenus] == 1, "root has exactly one submenu");
    id leaf = root != nil ? [root getSubmenu: 0] : nil;
    check (leaf != nil && [leaf isLeafNode], "leaf node");
    check (leaf != nil && [[leaf getNameAsString] isEqualToString: @"Zero"], "leaf is named Zero");
    check (leaf != nil && [NSStringFromSelector ([leaf getMessage]) isEqualToString: @"zeroSound:"],
           "leaf targets zeroSound:");
    check (leaf != nil && [leaf getReceiver] == module, "leaf targets the module");

    /* The DSP core: the five 1998 formats, mono and stereo. */
    Ivar ivar = class_getInstanceVariable ([module class], "moduleController");
    check (ivar != NULL, "moduleController ivar (for the DSP cases)");
    int c;
    for (c = 0; c < 5; c++)
        testZeroing (module, (SndSampleFormat)dspFormats[c], 1);
    for (c = 0; c < 5; c++)
        testZeroing (module, (SndSampleFormat)dspFormats[c], 2);
}

static void runMix (Class principal)
{
    /* The menu tree the app's Modules menu is built from. */
    id module = [[principal alloc] init];
    check (module != nil, "module instantiation");
    id root = [module getModuleMenuNode];
    check (root != nil, "root menu node");
    check (root != nil && [root numSubmenus] == 1, "root has exactly one submenu");
    id leaf = root != nil ? [root getSubmenu: 0] : nil;
    check (leaf != nil && [leaf isLeafNode], "leaf node");
    check (leaf != nil && [[leaf getNameAsString] isEqualToString: @"Mix In"], "leaf is named Mix In");
    check (leaf != nil && [NSStringFromSelector ([leaf getMessage]) isEqualToString: @"mix:"],
           "leaf targets mix:");
    check (leaf != nil && [leaf getReceiver] == module, "leaf targets the module");

    Ivar ivar = class_getInstanceVariable ([module class], "moduleController");
    check (ivar != NULL, "moduleController ivar (for the DSP cases)");

    /* The empty-pasteboard no-op first (it can only run before the
       cases below write to the pasteboard). */
    testMixNoop (module, ivar);

    /* The five 1998 formats, mono and stereo: a 50-frame source
       selection mixed into a 50-frame document selection. */
    int c;
    int ch;
    for (c = 0; c < 5; c++)
        for (ch = 1; ch <= 2; ch++)
            testMix (module, ivar, (SndSampleFormat)dspFormats[c], ch, 10, 50, 60, 50);

    /* And the same with a paste shorter than the selection (30
       frames into a 50-frame selection): the mix covers the first
       30 frames of the selection, the rest of the document stays
       untouched. */
    for (c = 0; c < 5; c++)
        for (ch = 1; ch <= 2; ch++)
            testMix (module, ivar, (SndSampleFormat)dspFormats[c], ch, 10, 30, 150, 50);
}

int main (int argc, char **argv)
{
    NSString *rmod = argc > 1
        ? [NSString stringWithUTF8String: argv[1]]
        : @"../Source/Modules/Zero/Zero.rmod";
    NSBundle *bundle;
    Class principal;

    printf ("resoundmodule: %s\n", [rmod UTF8String]);

    bundle = [[NSBundle alloc] initWithPath: rmod];
    check (bundle != nil, "NSBundle initWithPath");
    if (bundle == nil)
        return 1;

    /* 1. The principal class decides the contract, exactly like the
       app's ModuleController loadAModule: (NSBundle principalClass). */
    principal = [bundle principalClass];
    check (principal != Nil, "principalClass is loaded");
    if (principal == Nil)
        return 1;
    check ([NSStringFromClass (principal) length] > 0, "principal class has a name");
    if ([NSStringFromClass (principal) isEqualToString: @"ZeroModule"])
        runZero (principal);
    else if ([NSStringFromClass (principal) isEqualToString: @"MixModule"])
        runMix (principal);
    else
        check (NO, "principal class is neither ZeroModule nor MixModule");

    if (failures == 0)
        printf ("resoundmodule: all checks passed\n");
    else
        printf ("resoundmodule: %d check(s) failed\n", failures);
    return failures == 0 ? 0 : 1;
}
