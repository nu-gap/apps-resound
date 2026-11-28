/*
resoundmodule
For the GNUstep port of Resound (gnustep-port branch)

The Phase 3 load contracts for the ported modules - the Zero
module (zeroSound:), the Mix module (mix:), the Envelope module
(applyEnvelope:), the EchoChamber module (begin:/performEcho:),
the Gate module (showNoiseGatePanel:/gateIt:), the Filter module
(LoadFilterPanel:/Apply:/ApplyEcho:), the WaveBuilder module
(loadSinPanel:/generateSin:/generateOthers:), the FFT module
(showFFTPanel:/doFFT: with the bundle's real FFTController), the
Math module (absIt:/invertIt:/multiplyIt:/shiftIt:/maximize: /
reverseIt: and the two lazy panel loads) and the Channel module
(swap:/stripLeft:/stripRight:/addLeft:/addRight:) - the whole
module tree, all ten units (see docs/GNUSTEP_BUILD.md).

What it does (headless: no display, no audio device):

  1. Loads the built module bundle through NSBundle and checks the
     principal class.  The app's ModuleController loadAModule: does
     exactly this - the bundle's generated Info-gnustep.plist carries
     NSPrincipalClass, and the principal class is the class the app
     instantiates - so the test dispatches on the class name, exactly
     like the app: ZeroModule runs the zero contract, MixModule the
     mix contract, EnvelopeModule the envelope contract,
     EchoChamber the echo contract, GateModule the gate contract,
     FilterModule the filter contract, WaveBuilderModule the wave
     builder contract, FFTModule the FFT contract, MathModule the
     math contract, ChannelModule the channel contract.

  2. Instantiates the module (the same alloc/init the app runs) and
     checks the menu tree the 1998 init builds: exactly one leaf -
     named "Zero" targeting zeroSound:, or "Mix In" targeting mix:,
     or "Envelope" targeting showEnvelopePanel:, or "Echo
     Chamber..." targeting begin:, or "Noise Gate..." targeting
     showNoiseGatePanel: - or, the Filter module, the first with
     two, one "Filter" submenu holding the leaves "Comb
     Filter..." and "Echo Filter...", or, the WaveBuilder module,
     the first generator, one "Generate Sounds" submenu holding
     the leaves "Sine Harmonics..." and "Other Waves...",
     on the module itself - what the app's "Modules" menu shows
     after the load.  The gorm-wired modules additionally expose
     their private ivars here (the Envelope panel outlets, the
     EchoChamber value outlets and windowLoaded flag, the Gate
     panel outlets and nib_loaded flag, the Filter panel outlets
     and WindowLoaded flag, the WaveBuilder panel outlets and
     windowLoaded flag, the FFT panel outlets and nib_loaded
     flag), all checked to exist and to start in
     the un-wired state.

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
         calls so the expectation mirrors the port exactly;
       - applyEnvelope: (the fade in/out DSP): over a selection of
         the in-memory sound, per channel, over the five 1998 data
         formats, the expected buffer computed with the module's own
         per-format multiply arithmetic (mu-law through SndKit's
         conversion pair).  The panel's six outlets stand in as
         fakes: pre-setting the panel outlet skips the nib load the
         module performs for a real panel (the real load needs a
         display and runs in the app; the resoundmenu --perform
         probe drives it there);
        - performEcho: (the echo DSP) on the one sound shape the
          1998 method accepts without its modal conversion prompt -
          mono, 16-bit linear, 44.1k - the expected buffer computed
          with the module's own echo arithmetic, the five panel
          value outlets as fakes (their gorm types - text field and
          slider cells - only ever answer floatValue), the view and
          controller doubles recording the setSound:/newSound:for:
          hand-off of the freshly built sound;
         - gateIt: (the noise gate DSP) over the in-memory sound's
           selection, per channel, over the five 1998 data formats,
           whole-sound and partial - the expected buffer computed
           with the module's own per-format gate state machine
           (mu-law through SndKit's conversion pair, the 1998 abs()
           arithmetic mirrored), the three panel value outlets as
           fakes, and the panel window with the nib_loaded flag
           pre-set to skip the nib load the module performs for a
           real panel (the app-side half is the resoundmenu
           --perform probe);
          - Apply:sender / ApplyEcho: (the comb and echo filter
           DSP) on the one sound shape the 1998 methods accept
           without their modal conversion prompt - mono, 16-bit
           linear, 44.1k - the expected buffer computed with the
           module's own comb / echo arithmetic (the signed-short
           accumulator, the minval/maxval zero scans, the 1998
           Max/Min clamp, the 1998 <= 0 range quirk), the panel's
           matrices and progress fields as fakes, the view and
           controller doubles recording the setSound:/newSound:for:
           hand-off of the freshly built (resized) sound.
          - generateSin: / generateOthers: (the sine and waveform
           generation) building a fresh 16-bit mono 44.1k sound
           from the panel values - the first contract with no
           current sound at all: the expected buffer computed with
           the module's own 1998 arithmetic (the harmonic sines
           with the SHRT_MAX/SHRT_MIN clamps, the five waveform
           functions, the noise through the re-seeded rand()
           sequence), the panels, the pull-down and the six text
           fields as fakes with the windowLoaded flag pre-set, the
           ModuleController double recording the brandNewSound:
           hand-off, and the note actions' string writes checked
           against the 1998 %f / %d formatting.
          - showFFTPanel: with the panel outlets as fakes and the
            one-byte nib_loaded flag pre-set (skipping the nib
            load, which needs a display and runs in the app; the
            resoundmenu --perform probe drives it there for real),
            then doFFT: - the FFT DSP - on the one sound shape the
            1998 method accepts without its modal conversion
            prompt - mono, 44.1k - over the five 1998 data formats
            and whole-sound and partial selections, the real
            bundle FFTController driven on a real in-memory Snd and
            a real SndView, the two graph views, the minimum-dB
            field and the decibel button as fakes, and the
            controller's
            f1/f2/p1 buffers and the graph setTo:/setReals:/
            display calls checked against the same real Snd
            performFFTFromSoundData: the module calls (compiled
            into this tool from the app's Source/ModuleSound.m
            plus the 1998 fft.c core).

The controller is injected by setting the module's private
moduleController ivar directly (object_setIvar): the app's own wiring
goes through setModuleControllerTo:, whose protocol-conformance check
a duck-typed double does not pass; the contract under test is the
same either way (the module only reads the ivar).  The Envelope
panel's six outlets are injected the same way: the app wires them
from the module's gorm panel when it loads, and the gate stands in
fakes for whatever that wiring would have provided (the 1998 nib
leaves the applyToAllButton outlet unconnected, so in the app it
stays nil - the gate's fakes drive the states explicitly instead).
So are the EchoChamber's five value outlets, the Gate panel's
three value outlets and panel window, and the Filter's eight
outlets - its slider, position and amplitude matrices, its two
progress fields, the recursive button, the two panel windows -
whose WindowLoaded flag is a full int, so a plain pointer-sized
object_setIvar is exact on it.  So are the WaveBuilder's fifteen
outlets - its six 16x1 matrices, its six text fields at their
gorm values, its pull-down, its two panel windows - whose
windowLoaded flag is a full int the same pointer-sized set is
exact on; and the generator's hand-off partner, the app's
ModuleController, stands in as the double that records the
brandNewSound: the 1998 module finishes with.  So are the FFT
module's four outlets - its panel window, the two axis fields and
the real bundle FFTController - whose four own outlets (the two
graph views, the minimum-dB field and the decibel button) the
contract fills with fakes the same way; the fftController ivar
takes the real class from the loaded bundle, so the contract drives
the 1998 controller itself, the module's double answering
currentSound / currentSoundView with a real in-memory Snd and a
real SndView.  The Gate's and the FFT module's nib_loaded flag is a
one-byte BOOL - the 1998 header declares it
ahead of the four outlet pointers - so a pointer-sized
object_setIvar on it would write into the outlets' bytes; those
contracts read and write it through the type-encoding-aware
sized ivar helpers instead.

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
#import <limits.h>
#import <float.h>
#import <stdlib.h>
#include <string.h>
#include <math.h>

/* The app's copy of the module base classes, the same files the tool
   compiles in below (../Source/Module.m) - one path for the shared
   headers, so #import dedupes them. */
#import "../Source/Module.h"

/* Minimal local mirrors of the six module headers, instead of the
   module directories' copies: those import the module-directory
   copies of the base headers (a second path for the same classes),
   which #import would reject as duplicate interface definitions once
   the app's ../Source copies are in.  The contracts only need the
   class names and the selectors they drive; the bundles under test
   supply the implementations (and their real headers stay next to
   them, where the bundles' own builds use them). */
@interface ZeroModule : Module
- init;
- zeroSound:sender;
@end

@interface MixModule : Module
- init;
- mix:sender;
@end

@interface EnvelopeModule : Module
- init;
- soundDidChange;
- showEnvelopePanel:sender;
- applyEnvelope:sender;
@end

@interface EchoChamber : Module
- init;
- begin:sender;
- performEcho:sender;
@end

/* The 1998 header declares gateIt: (the gorm-wired Apply control)
   but not showNoiseGatePanel: (the menu leaf's target - the 1998
   header simply left it out of the interface); the mirror carries
   both, in the no-space shapes the 1998 code uses, which clang
   builds into the clean one-argument selectors the 1998 menu node
   and the gorm matrix fire. */
@interface GateModule : Module
- init;
- showNoiseGatePanel:sender;
- gateIt:sender;
@end

/* The 1998 Filter module keeps its olden-days capitalization (the
   header's note: methods, classes and instance variables all
   capitalized, deliberately unconverted).  The shapes matter: the
   1998 code writes every method with no space after the colon
   (- LoadFilterPanel:sender, - Apply:sender, ...): the no-space
   "sender" reads as the parameter name, so each method's selector
   is the part before the colon - LoadFilterPanel:,
   LoadEchoFilterPanel:, Apply:, ApplyEcho: - exactly what the
   gorm buttons and the 1998 nib fire.  (That colon-abuts-the-name
   shape warns nothing, so the TU's warning baseline is unchanged;
   the app's newWindow warns because its no-space sits between the
   name and the colon instead.)  The mirror carries the 1998
   shapes byte-faithful. */
@interface FilterModule : Module
- init;
- LoadFilterPanel:sender;
- LoadEchoFilterPanel:sender;
- Apply:sender;
- ApplyEcho:sender;
- (int) Max;
- (int) Min;
@end

/* The 1998 WaveBuilder header is the plain one: every method with
   the space after the colon, so the selectors are the part after
   the space - generateSin:, A:, doNoise:, ... - and the mirror
   carries the 1998 shapes byte-faithful. */
@interface WaveBuilderModule : Module
- init;
- generateSin:sender;
- generateOthers:sender;
- loadSinPanel:sender;
- loadOthersPanel:sender;
- A:sender;
- As:sender;
- B:sender;
- C:sender;
- Cs:sender;
- D:sender;
- Ds:sender;
- E:sender;
- F:sender;
- Fs:sender;
- G:sender;
- Gs:sender;
- cosA:sender;
- clear:sender;
- doNoise:sender;
- doSquare:sender;
- doPulse:sender;
- doTriangle:sender;
- doSawtooth:sender;
@end

/* The 1998 FFT header keeps the original drawFFT: / setDelegates:
   shapes: a type abutting the next colon (drawFFT:(Snd*)
   this_sound:) and bare names between the colons (setDelegates:
   x:y).  Each of those tokens reads as the parameter name rather
   than the selector part - the -Wmissing-selector-name warnings
   they cost this TU are measured in the unit's build log - so the
   selectors are the leading part plus one empty component per
   argument: drawFFT::: and setDelegates:: - the same four- and
   two-argument calls the 1998 module generates.  showFFTPanel: and
   doFFT: are the plain shapes the 1998 menu leaf fires, and
   toggleLinearAndDecibel: / redrawGraphs: the plain shapes the
   gorm's button fires on the controller. */
@interface FFTModule : Module
- init;
- showFFTPanel:sender;
- doFFT:sender;
@end

@interface FFTController : NSObject
- drawFFT:(Snd*) this_sound:(SndView*)
		this_soundview: (int)start_sample:(int)number_samples;
- setDelegates:x:y;
- init;
- toggleLinearAndDecibel:sender;
- redrawGraphs:sender;
@end

/* The 1998 Math header is the plain one: every method with the
   space after the colon, so the selectors are the part after the
   space - reverseIt:, invertIt:, absIt:, shiftIt:, multiplyIt:,
   showShiftPanel:, showMultiplyPanel:, halve:, double:, maximize:
   - and the mirror carries them byte-faithful (no warnings). */
@interface MathModule : Module
- init;
- reverseIt:sender;
- invertIt:sender;
- absIt:sender;
- shiftIt:sender;
- multiplyIt:sender;
- showShiftPanel:sender;
- showMultiplyPanel:sender;
- halve:sender;
- double:sender;
- maximize:sender;
@end

@interface ChannelModule : Module
- init;
- swap:sender;
- stripLeft:sender;
- stripRight:sender;
- addLeft:sender;
- addRight:sender;
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

/* Raw reads of the module's private ivars (the gate inspects the same
   state the gorm wiring writes): object ivars by pointer, the int
   windowLoaded flag through its raw bits. */
static id readObjIvar (id obj, const char *name)
{
    Ivar iv = class_getInstanceVariable ([obj class], name);
    return iv ? object_getIvar (obj, iv) : nil;
}

static long readIntIvar (id obj, const char *name)
{
    Ivar iv = class_getInstanceVariable ([obj class], name);
    return iv ? (long)(intptr_t)object_getIvar (obj, iv) : -999999;
}

/* Sized reads and writes of non-object ivars, the width taken from
   the ivar's type encoding: the gate's nib_loaded flag is a
   one-byte BOOL, and the 1998 header declares it ahead of the four
   outlet pointers - a pointer-sized object_setIvar on it would
   write into the outlets' bytes (and object_getIvar reads the same
   over-wide span).  Pointer ivars (the outlets) keep going through
   object_getIvar/object_setIvar, where the width is exactly right. */
static long readSizedIvar (id obj, const char *name)
{
    Ivar iv = class_getInstanceVariable ([obj class], name);
    if (iv == NULL)
        return -999999;
    const char *enc = ivar_getTypeEncoding (iv);
    if (enc == NULL)
        return -999999;
    char *p = (char *)(void *)obj + ivar_getOffset (iv);
    switch (enc[0])
    {
    case 'c':
    case 'C':
    case 's':
    case 'S':
        return *p;
    case 'i':
    case 'l':
        return *(int32_t *)p;
    case 'q':
    case 'L':
        return *(int64_t *)p;
    default:
        return -999999;
    }
}

static void writeSizedIvar (id obj, const char *name, long value)
{
    Ivar iv = class_getInstanceVariable ([obj class], name);
    if (iv == NULL)
        return;
    const char *enc = ivar_getTypeEncoding (iv);
    if (enc == NULL)
        return;
    char *p = (char *)(void *)obj + ivar_getOffset (iv);
    switch (enc[0])
    {
    case 'c':
    case 'C':
    case 's':
    case 'S':
        *p = (char)value;
        break;
    case 'i':
    case 'l':
        *(int32_t *)p = (int32_t)value;
        break;
    case 'q':
    case 'L':
        *(int64_t *)p = (int64_t)value;
        break;
    default:
        break;
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
Stand-ins for the Envelope panel's controls: duck-typed doubles for
the gorm's NSButton/NSMatrix cells, answering the selectors the
module's showEnvelopePanel:/applyEnvelope: send (state, enabled,
selectedCell, tag, orderFront:).  The fakes double as the
assertion targets - each records what the module did to the panel.
*/
@interface FakeEnvelopeButton : NSObject
{
    int _state;
    int _enabled;
}
- (int) state;
- (void) setState: (int)state;
- (int) enabled;
- (void) setEnabled: (BOOL)enabled;
@end

@implementation FakeEnvelopeButton
- (int) state
    {
    return _state;
    }
- (void) setState: (int)state
    {
    _state = state;
    }
- (int) enabled
    {
    return _enabled;
    }
- (void) setEnabled: (BOOL)enabled
    {
    _enabled = enabled;
    }
@end

@interface FakeEnvelopeCell : NSObject
{
    int _tag;
}
- (int) tag;
- (void) setTag: (int)tag;
@end

@implementation FakeEnvelopeCell
- (int) tag
    {
    return _tag;
    }
- (void) setTag: (int)tag
    {
    _tag = tag;
    }
@end

@interface FakeEnvelopeMatrix : NSObject
{
    FakeEnvelopeCell *_cell;
}
- (FakeEnvelopeCell *) selectedCell;
@end

@implementation FakeEnvelopeMatrix
- init
    {
    if (self = [super init])
        _cell = [[FakeEnvelopeCell alloc] init];
    return self;
    }
- (void) dealloc
    {
    [_cell release];
    [super dealloc];
    }
- (FakeEnvelopeCell *) selectedCell
    {
    return _cell;
    }
@end

@interface FakeEnvelopePanel : NSObject
{
    int _orderFrontCount;
}
- (void) orderFront: (id)sender;
- (int) orderFrontCount;
@end

@implementation FakeEnvelopePanel
- (void) orderFront: (id)sender
    {
    _orderFrontCount++;
    }
- (int) orderFrontCount
    {
    return _orderFrontCount;
    }
@end

/*
A stand-in for the sound view with a settable selection: the module's
applyEnvelope: takes its (firstSample, sampleLength) from
-[SndView getSelection:].  The real SndView's
checkForCurrentDataOnPasteboard: (which the 1998 flow calls before
the DSP) would touch the general pasteboard; the fake is a no-op, so
the Envelope contract needs no pasteboard server at all.
*/
@interface FakeEnvelopeView : NSObject
{
    Snd *_sound;
    unsigned int _first;
    unsigned int _len;
}
- (id) initWithSound: (Snd *)sound;
- (void) setSelection: (unsigned int)first size: (unsigned int)len;
- (void) getSelection: (unsigned int *)firstSample size: (unsigned int *)sampleLength;
- (void) checkForCurrentDataOnPasteboard;
@end

@implementation FakeEnvelopeView
- (id) initWithSound: (Snd *)sound
    {
    if (self = [super init])
    {
        _sound = [sound retain];
        _first = 0;
        _len = (unsigned int)[_sound lengthInSampleFrames];
    }
    return self;
    }
- (void) dealloc
    {
    [_sound release];
    [super dealloc];
    }
- (void) setSelection: (unsigned int)first size: (unsigned int)len
    {
    _first = first;
    _len = len;
    }
- (void) getSelection: (unsigned int *)firstSample size: (unsigned int *)sampleLength
    {
    *firstSample = _first;
    *sampleLength = _len;
    }
- (void) checkForCurrentDataOnPasteboard
    {
    /* The app's ModuleSoundView category clears a stale pasteboard; a no-op here. */
    }
@end

/*
A stand-in for the app's ModuleController for the Envelope contract:
it answers currentSound / currentSoundView / currentWindow and
records the three side effects applyEnvelope: and soundDidChange
produce (stop, soundChanged, runLongTimePanel).
*/
@interface FakeEnvelopeController : NSObject
{
    Snd *_sound;
    id _soundView;
    id _window;
    int _stopped;
    int _soundChanged;
    int _longTime;
}
- (id) initWithSound: (Snd *)sound soundView: (id)soundView window: (id)window;
- (id) currentSound;
- (id) currentSoundView;
- (id) currentWindow;
- (void) stop;
- (void) soundChanged;
- (BOOL) runLongTimePanel;
- (int) stoppedCount;
- (int) soundChangedCount;
- (int) longTimeCount;
@end

@implementation FakeEnvelopeController
- initWithSound: (Snd *)sound soundView: (id)soundView window: (id)window
    {
    if (self = [super init])
    {
        _sound = [sound retain];
        _soundView = [soundView retain];
        _window = [window retain];
        _stopped = 0;
        _soundChanged = 0;
        _longTime = 0;
    }
    return self;
    }
- (void) dealloc
    {
    [_sound release];
    [_soundView release];
    [_window release];
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
- (id) currentWindow
    {
    return _window;
    }
- (void) stop
    {
    _stopped++;
    }
- (void) soundChanged
    {
    _soundChanged++;
    }
- (BOOL) runLongTimePanel
    {
    _longTime++;
    return YES;
    }
- (int) stoppedCount
    {
    return _stopped;
    }
- (int) soundChangedCount
    {
    return _soundChanged;
    }
- (int) longTimeCount
    {
    return _longTime;
    }
@end

/*
A duck-typed double for one of the EchoChamber panel's five value
outlets: the gorm wires three of them (delay, dropoff, initial) to
text field cells and two (firstDelay, ratio) to slider cells, and the
module reads all five only through floatValue - which the probe of the
real gorm wiring confirmed.
*/
@interface FakeEchoValue : NSObject
{
    float _value;
}
- (id) initWithValue: (float)value;
- (float) floatValue;
@end

@implementation FakeEchoValue
- initWithValue: (float)value
    {
    if (self = [super init])
        _value = value;
    return self;
    }
- (float) floatValue
    {
    return _value;
    }
@end

/*
A stand-in for the EchoChamber panel window: records the
makeKeyAndOrderFront: the 1998 begin: sends it.  Pre-setting this
outlet - together with the windowLoaded flag - is what makes begin:
skip the nib load, which needs a display (the app-side half is the
resoundmenu --perform probe).
*/
@interface FakeEchoPanel : NSObject
{
    int _keyFront;
}
- (void) makeKeyAndOrderFront: (id)sender;
- (int) keyFrontCount;
@end

@implementation FakeEchoPanel
- (void) makeKeyAndOrderFront: (id)sender
    {
    _keyFront++;
    }
- (int) keyFrontCount
    {
    return _keyFront;
    }
@end

/*
A stand-in for the document sound view for the performEcho: contract:
it records the setSound: hand-off and no-ops the
checkForCurrentDataOnPasteboard: the 1998 flow calls (the app's
ModuleSoundView category clears a stale pasteboard; a no-op keeps the
contract away from the pasteboard server, as the Envelope cases do).
*/
@interface FakeEchoView : NSObject
{
    id _sound;
    int _setSoundCount;
}
- (void) setSound: (id)sound;
- (id) sound;
- (int) setSoundCount;
- (void) checkForCurrentDataOnPasteboard;
@end

@implementation FakeEchoView
- (void) dealloc
    {
    [_sound release];
    [super dealloc];
    }
- (void) setSound: (id)sound
    {
    if (sound != _sound)
        {
        [_sound release];
        _sound = [sound retain];
        }
    _setSoundCount++;
    }
- (id) sound
    {
    return _sound;
    }
- (int) setSoundCount
    {
    return _setSoundCount;
    }
- (void) checkForCurrentDataOnPasteboard
    {
    /* no-op, as in the other view doubles */
    }
@end

/*
A stand-in for the app's ModuleController for the performEcho:
contract: it answers currentSound / currentSoundView and records the
newSound:for: hand-off the 1998 flow finishes with.

The newSound:for: declaration keeps the 1998 space-separated shape the
app's ModuleController.h carries (a space after the colon keeps the
parameter name out of the selector, so clang builds the clean
newSound:for: with no warning - the same 13-byte selector the 1998
labeled module call generates).
*/
@interface FakeEchoController : NSObject
{
    Snd *_sound;
    id _soundView;
    id _newSound;
    id _newSoundView;
    int _newSoundCount;
}
- initWithSound: (Snd *)sound soundView: (id)soundView;
- (id) currentSound;
- (id) currentSoundView;
- (void) newSound: (id)thisSound for: (id)thisSoundView;
- (int) newSoundCount;
- (id) newSoundArg;
- (id) newSoundViewArg;
@end

@implementation FakeEchoController
- initWithSound: (Snd *)sound soundView: (id)soundView
    {
    if (self = [super init])
        {
        _sound = [sound retain];
        _soundView = [soundView retain];
        _newSound = nil;
        _newSoundView = nil;
        _newSoundCount = 0;
        }
    return self;
    }
- (void) dealloc
    {
    [_sound release];
    [_soundView release];
    [_newSound release];
    [_newSoundView release];
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
- (void) newSound: (id)thisSound for: (id)thisSoundView
    {
    [_newSound release];
    [_newSoundView release];
    _newSound = [thisSound retain];
    _newSoundView = [thisSoundView retain];
    _newSoundCount++;
    }
- (int) newSoundCount
    {
    return _newSoundCount;
    }
- (id) newSoundArg
    {
    return _newSound;
    }
- (id) newSoundViewArg
    {
    return _newSoundView;
    }
@end

/*
A duck-typed double for one of the Gate panel's three value
outlets: the gorm wires all three (threshold, secondsWait,
secondsCut) to text field views (the probe of the real
wiring), and the module's gateIt: reads all three only
through floatValue - the same gorm cell behaviour the
EchoChamber values rely on.
*/
@interface FakeGateValue : NSObject
{
    float _value;
}
- initWithValue: (float)value;
- (float) floatValue;
@end

@implementation FakeGateValue
- initWithValue: (float)value
    {
    if (self = [super init])
        _value = value;
    return self;
    }
- (float) floatValue
    {
    return _value;
    }
@end

/*
A stand-in for the Gate panel window: records the
makeKeyAndOrderFront: the 1998 showNoiseGatePanel: sends it.
With the panel pre-set - and the nib_loaded flag pre-set
through the sized ivar helpers - the method skips the nib
load the module performs for a real panel (that needs a
display; the app-side half is the resoundmenu --perform
probe, where the gorm panel comes up for real).
*/
@interface FakeGatePanel : NSObject
{
    int _keyFront;
}
- (void) makeKeyAndOrderFront: (id)sender;
- (int) keyFrontCount;
@end

@implementation FakeGatePanel
- (void) makeKeyAndOrderFront: (id)sender
    {
    _keyFront++;
    }
- (int) keyFrontCount
    {
    return _keyFront;
    }
@end

/*
A stand-in for the document sound view with a settable
selection: the module's gateIt: takes its (firstSample,
sampleLength) from -[SndView getSelection:] (a zero length
meaning the whole sound) and calls
checkForCurrentDataOnPasteboard on the view first.  The
no-op pasteboard (as in the other view doubles) keeps the
contract away from the pasteboard server.
*/
@interface FakeGateView : NSObject
{
    Snd *_sound;
    unsigned int _first;
    unsigned int _len;
}
- (id) initWithSound: (Snd *)sound;
- (void) setSelection: (unsigned int)first size: (unsigned int)len;
- (void) getSelection: (unsigned int *)firstSample size: (unsigned int *)sampleLength;
- (void) checkForCurrentDataOnPasteboard;
@end

@implementation FakeGateView
- (id) initWithSound: (Snd *)sound
    {
    if (self = [super init])
        {
        _sound = [sound retain];
        _first = 0;
        _len = (unsigned int)[_sound lengthInSampleFrames];
    }
    return self;
    }
- (void) dealloc
    {
    [_sound release];
    [super dealloc];
    }
- (void) setSelection: (unsigned int)first size: (unsigned int)len
    {
    _first = first;
    _len = len;
    }
- (void) getSelection: (unsigned int *)firstSample size: (unsigned int *)sampleLength
    {
    *firstSample = _first;
    *sampleLength = _len;
    }
- (void) checkForCurrentDataOnPasteboard
    {
    /* no-op, as in the other view doubles */
    }
@end

/*
A stand-in for the app's ModuleController for the gateIt:
contract: it answers currentSound / currentSoundView and
records the two side effects the 1998 flow produces (stop
before the DSP, soundChanged after it).
*/
@interface FakeGateController : NSObject
{
    Snd *_sound;
    id _soundView;
    int _stopped;
    int _soundChanged;
}
- (id) initWithSound: (Snd *)sound soundView: (id)soundView;
- (id) currentSound;
- (id) currentSoundView;
- (void) stop;
- (void) soundChanged;
- (int) stoppedCount;
- (int) soundChangedCount;
@end

@implementation FakeGateController
- initWithSound: (Snd *)sound soundView: (id)soundView
    {
    if (self = [super init])
        {
        _sound = [sound retain];
        _soundView = [soundView retain];
        _stopped = 0;
        _soundChanged = 0;
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
    _stopped++;
    }
- (void) soundChanged
    {
    _soundChanged++;
    }
- (int) stoppedCount
    {
    return _stopped;
    }
- (int) soundChangedCount
    {
    return _soundChanged;
    }
@end

/*
A stand-in for one of the Filter panel's value cells: the 1998
code drives its 65 slider cells, its eight position cells, its
eight amplitude cells, its recursive button and its two progress
fields through floatValue / intValue and setFloatValue: /
setIntValue:, so one fake serves all of them.

Each cell wraps one slot of its matrix's slot array (a float and
an int, the un-wired zero state): the matrix's cellAtRow:column:
hands out a fresh autoreleased cell per call, all wrapping the
same slot, so a set on any of them is what the 1998 code then
reads back.
*/
struct FakeFilterSlot
{
    float f;
    int i;
};
@interface FakeFilterValue : NSObject
{
    struct FakeFilterSlot *_slot;
    BOOL _ownsSlot;
}
- (id) initWithSlot: (struct FakeFilterSlot *)slot;
- (float) floatValue;
- (int) intValue;
- (void) setFloatValue: (float)value;
- (void) setIntValue: (int)value;
@end

@implementation FakeFilterValue
- init
    {
    if (self = [super init])
        {
        _slot = calloc (1, sizeof (struct FakeFilterSlot));
        _ownsSlot = YES;
        }
    return self;
    }
- (id) initWithSlot: (struct FakeFilterSlot *)slot
    {
    if (self = [super init])
        {
        _slot = slot;
        _ownsSlot = NO;
        }
    return self;
    }
- (void) dealloc
    {
    if (_ownsSlot)
        free (_slot);
    [super dealloc];
    }
- (float) floatValue
    {
    return _slot->f;
    }
- (int) intValue
    {
    return _slot->i;
    }
- (void) setFloatValue: (float)value
    {
    _slot->f = value;
    }
- (void) setIntValue: (int)value
    {
    _slot->i = value;
    }
@end

/*
A stand-in for the Filter panel's three matrices (the 65-tap
slider matrix, the eight position cells, the eight amplitude
cells - the 1998 code reaches all of them through
cellAtRow:column:): an eight-by-sixty-five slot array (a plain
C struct grid - Clang neither subscripts nor does pointer
arithmetic on object pointers), the un-wired state the gorm
would leave them in.
*/
#define FILTER_ROWS 8
#define FILTER_COLUMNS 65
@interface FakeFilterMatrix : NSObject
{
    struct FakeFilterSlot *_slots;
}
- (id) cellAtRow: (int)row column: (int)column;
@end

@implementation FakeFilterMatrix
- init
    {
    if (self = [super init])
        _slots = calloc (FILTER_ROWS * FILTER_COLUMNS,
                         sizeof (struct FakeFilterSlot));
    return self;
    }
- (void) dealloc
    {
    free (_slots);
    [super dealloc];
    }
- (id) cellAtRow: (int)row column: (int)column
    {
    if (row < 0 || row >= FILTER_ROWS || column < 0 || column >= FILTER_COLUMNS)
        return nil;
    return [[ [FakeFilterValue alloc] initWithSlot:
                     _slots + row * FILTER_COLUMNS + column ] autorelease];
    }
@end

/*
A stand-in for the Filter panel windows: records the
makeKeyAndOrderFront: the 1998 Load...Panel: methods send them.
*/
@interface FakeFilterPanel : NSObject
{
    int _keyFront;
}
- (void) makeKeyAndOrderFront: (id)sender;
- (int) keyFrontCount;
@end

@implementation FakeFilterPanel
- (void) makeKeyAndOrderFront: (id)sender
    {
    _keyFront++;
    }
- (int) keyFrontCount
    {
    return _keyFront;
    }
@end

/*
A stand-in for the app's sound view: records the setSound:
hand-off of the freshly built sound, and answers the pasteboard
check the 1998 methods run on it.  (The modal conversion
prompt's convertToSampleFormat: is deliberately absent - a
conforming sound never reaches it, and the headless gate must not
exercise it.)
*/
@interface FakeFilterView : NSObject
{
    Snd *_sound;
    int _soundSet;
    int _pasteboard;
}
- (id) initWithSound: (Snd *)sound;
- (Snd *) sound;
- (int) soundSetCount;
- (int) pasteboardCheckCount;
- (void) setSound: (Snd *)sound;
- (void) checkForCurrentDataOnPasteboard;
@end

@implementation FakeFilterView
- initWithSound: (Snd *)sound
    {
    if (self = [super init])
        {
        _sound = [sound retain];
        _soundSet = 0;
        _pasteboard = 0;
        }
    return self;
    }
- (void) dealloc
    {
    [_sound release];
    [super dealloc];
    }
- (Snd *) sound
    {
    return _sound;
    }
- (int) soundSetCount
    {
    return _soundSet;
    }
- (int) pasteboardCheckCount
    {
    return _pasteboard;
    }
- (void) setSound: (Snd *)sound
    {
    if (_sound != sound)
        {
        [_sound release];
        _sound = [sound retain];
        }
    _soundSet++;
    }
- (void) checkForCurrentDataOnPasteboard
    {
    _pasteboard++;
    }
@end

/*
A stand-in for the app's ModuleController (the duck-typed double
the other contracts inject through the moduleController ivar):
answers currentSound / currentSoundView, records the newSound:for:
hand-off the 1998 methods make, and answers the pasteboard
ownership test of the 1998 PASTE_BUG block with NO - the build
leaves the flag undefined, so the 1998 workaround never fires, as
in the shipped 1998 OpenStep build; the counters pin that here.
*/
@interface FakeFilterController : NSObject
{
    Snd *_sound;
    id _soundView;
    Snd *_newSound;
    int _handOffs;
    int _ownerQueries;
    int _invalidates;
}
- (id) initWithSound: (Snd *)sound soundView: (id)soundView;
- (id) currentSound;
- (id) currentSoundView;
- (Snd *) newSound;
- (int) newSoundCount;
- (int) ownerQueryCount;
- (int) invalidateCount;
- (BOOL) isOwner: (id)object;
- (void) invalidatePasteboard;
@end

@implementation FakeFilterController
- initWithSound: (Snd *)sound soundView: (id)soundView
    {
    if (self = [super init])
        {
        _sound = [sound retain];
        _soundView = [soundView retain];
        _newSound = nil;
        _handOffs = 0;
        _ownerQueries = 0;
        _invalidates = 0;
        }
    return self;
    }
- (void) dealloc
    {
    [_sound release];
    [_soundView release];
    [_newSound release];
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
- (void) newSound: (Snd *)sound for: (id)view
    {
    if (_newSound != sound)
        {
        [_newSound release];
        _newSound = [sound retain];
        }
    _handOffs++;
    }
- (Snd *) newSound
    {
    return _newSound;
    }
- (int) newSoundCount
    {
    return _handOffs;
    }
- (BOOL) isOwner: (id)object
    {
    _ownerQueries++;
    return NO;
    }
- (int) ownerQueryCount
    {
    return _ownerQueries;
    }
- (void) invalidatePasteboard
    {
    _invalidates++;
    }
- (int) invalidateCount
    {
    return _invalidates;
    }
@end

/*
WaveBuilder, the seventh unit - the one that generates rather
than processes: its two panels ("Sine Wave Harmonics" and
"Other Waves") build a fresh 16-bit mono 44.1k sound from the
panel values and hand it off through brandNewSound: - no current
sound, no view, no pasteboard.
*/

/*
A stand-in for one of the WaveBuilder panel's text outlets (the
gorm wires the six fields the same way as the 16x1 matrix
cells; the module reaches them through floatValue / intValue on
the generate reads, setStringValue: on the note-action writes,
and setIntValue: on the percent counters).  The slot keeps the
string the 1998 text field would hold and derives the numbers
through the same NSNumber parsing the real cell does, so the
values travel the real path: string in, number out.
*/
struct FakeWaveFieldSlot
{
    char *c;                 /* the string, NULL for the empty one */
};

@interface FakeWaveField : NSObject
{
    struct FakeWaveFieldSlot *_slot;
    BOOL _ownsSlot;
}
- (id) init;
- (id) initWithSlot: (struct FakeWaveFieldSlot *)slot;
- (id) initWithString: (NSString *)string;
- (void) setStringValue: (NSString *)string;
- (NSString *) stringValue;
- (float) floatValue;
- (int) intValue;
- (void) setIntValue: (int)value;
@end

@implementation FakeWaveField
- init
    {
    if (self = [super init])
        {
        _slot = calloc (1, sizeof (struct FakeWaveFieldSlot));
        _ownsSlot = YES;
        _slot->c = strdup ("0");
        }
    return self;
    }
- (id) initWithSlot: (struct FakeWaveFieldSlot *)slot
    {
    if (self = [super init])
        {
        _slot = slot;
        _ownsSlot = NO;
        }
    return self;
    }
- (id) initWithString: (NSString *)string
    {
    if (self = [super init])
        {
        _slot = calloc (1, sizeof (struct FakeWaveFieldSlot));
        _ownsSlot = YES;
        _slot->c = strdup (string ? [string UTF8String] : "");
        }
    return self;
    }
- (void) dealloc
    {
    if (_ownsSlot)
        {
        free (_slot->c);
        free (_slot);
        }
    [super dealloc];
    }
- (void) setStringValue: (NSString *)string
    {
    free (_slot->c);
    _slot->c = strdup (string ? [string UTF8String] : "");
    }
- (NSString *) stringValue
    {
    return [NSString stringWithUTF8String: _slot->c ? _slot->c : ""];
    }
- (float) floatValue
    {
    return [[self stringValue] floatValue];
    }
- (int) intValue
    {
    return [[self stringValue] intValue];
    }
- (void) setIntValue: (int)value
    {
    [self setStringValue: [NSString stringWithFormat: @"%d", value]];
    }
@end

#define WAVBUILDER_ROWS 16
#define WAVBUILDER_COLUMNS 1

/*
A stand-in for the WaveBuilder panel's six 16-row matrices (the
harmonic frequency / amplitude / phase values, and their text
twins): a 16x1 slot grid, the same plain-C-struct pattern as the
Filter matrix, whose cells are FakeWaveField instances bound to
the shared slots - a second cellAtRow: on the same cell sees the
first one's writes, as in the real matrix.
*/
@interface FakeSinMatrix : NSObject
{
    struct FakeWaveFieldSlot *_slots;
}
- (id) cellAtRow: (int)row column: (int)column;
@end

@implementation FakeSinMatrix
- init
    {
    if (self = [super init])
        {
        int i;
        _slots = calloc (WAVBUILDER_ROWS * WAVBUILDER_COLUMNS,
                         sizeof (struct FakeWaveFieldSlot));
        for (i = 0; i < WAVBUILDER_ROWS * WAVBUILDER_COLUMNS; i++)
            _slots[i].c = strdup ("0");
        }
    return self;
    }
- (void) dealloc
    {
    int i;
    for (i = 0; i < WAVBUILDER_ROWS * WAVBUILDER_COLUMNS; i++)
        free (_slots[i].c);
    free (_slots);
    [super dealloc];
    }
- (id) cellAtRow: (int)row column: (int)column
    {
    if (row < 0 || row >= WAVBUILDER_ROWS
        || column < 0 || column >= WAVBUILDER_COLUMNS)
        return nil;
    return [[ [FakeWaveField alloc] initWithSlot:
                 _slots + row * WAVBUILDER_COLUMNS + column ] autorelease];
    }
@end

/*
A stand-in for the WaveBuilder panel windows: records the
makeKeyAndOrderFront: the 1998 load...Panel: methods send them.
With the panels pre-set - and the 1998 full-int windowLoaded
flag pre-set the pointer-sized way the Filter contract does -
the methods skip the nib load the module performs for a real
panel (that needs a display; the app-side half is the
resoundmenu --perform probe, where the gorm panels come up for
real).
*/
@interface FakeWavePanel : NSObject
{
    int _keyFront;
}
- (void) makeKeyAndOrderFront: (id)sender;
- (int) keyFrontCount;
@end

@implementation FakeWavePanel
- (void) makeKeyAndOrderFront: (id)sender
    {
    _keyFront++;
    }
- (int) keyFrontCount
    {
    return _keyFront;
    }
@end

/*
A stand-in for the sin panel's pull-down (the gorm wires it to
the 1998 "Actions..." menu): the 1998 loadSinPanel: flips it to
pulls-down and re-sets its title - both recorded here.
*/
@interface FakeWavePopUp : NSObject
{
    BOOL _pullsDown;
    NSString *_title;
}
- (void) setPullsDown: (BOOL)down;
- (BOOL) pullsDown;
- (void) setTitle: (NSString *)title;
- (NSString *) title;
@end

@implementation FakeWavePopUp
- (void) dealloc
    {
    [_title release];
    [super dealloc];
    }
- (void) setPullsDown: (BOOL)down
    {
    _pullsDown = down;
    }
- (BOOL) pullsDown
    {
    return _pullsDown;
    }
- (void) setTitle: (NSString *)title
    {
    if (title != _title)
        {
        [_title release];
        _title = [title retain];
        }
    }
- (NSString *) title
    {
    return _title;
    }
@end

/*
A stand-in for the app's ModuleController for the WaveBuilder
contract: the 1998 module is a generator - it never reads the
document (no currentSound / currentSoundView call), and each
generation finishes with the brandNewSound: hand-off of the
freshly built sound, which this records.
*/
@interface FakeWaveController : NSObject
{
    id _newSound;
    int _handOffs;
}
- (void) brandNewSound: (id)thisSound;
- (id) newSound;
- (int) newSoundCount;
@end

@implementation FakeWaveController
- (void) dealloc
    {
    [_newSound release];
    [super dealloc];
    }
- (void) brandNewSound: (id)thisSound
    {
    if (_newSound != thisSound)
        {
        [_newSound release];
        _newSound = [thisSound retain];
        }
    _handOffs++;
    }
- (id) newSound
    {
    return _newSound;
    }
- (int) newSoundCount
    {
    return _handOffs;
    }
@end

/*
A stand-in for one of the FFT panel's two graph views
(the gorm wires the controller's freqview and phasview to two
DiscreteGraphViews).  It records the three graph calls the 1998
controller makes after the FFT - the setTo: range/format setup,
the setReals: data hand-off (the buffer copied, not the pointer
aliased, so the controller's realloc on the next drawFFT: cannot
dangle it) and the display - and the setDelegates: cursor pair.
The 1998 DiscreteGraphView declares setTo: with a type abutting
each next colon, so the selector is setTo::::: (one empty
component per argument); the fake reproduces that exact shape,
and its -Wmissing-selector-name warnings with it.
*/
#define DISCRETEGRAPHVIEW_FORMAT_MINMAX 0
#define DISCRETEGRAPHVIEW_FORMAT_HISTOGRAM 1
#define DISCRETEGRAPHVIEW_FORMAT_CENTERED_ON_ZERO 3

@interface FakeFftGraph : NSObject
{
    float _toMax;
    float _toMin;
    BOOL _stretchToMax;
    BOOL _stretchToMin;
    int _xScale;
    int _format;
    int _setToCount;
    float *_reals;
    int _realsSize;
    int _realsCount;
    int _displayCount;
    id _cursorX;
    id _cursorY;
    int _cursorCount;
}
- setTo:(float)maxVal:(float)minVal:(BOOL)stretchToMax:(BOOL)stretchToMin:
    (int)xScale:(int)format;
- setReals:(float*)r size:(int)s;
- (void)display;
- useCursor:x_d:y_d;
- (float) toMax;
- (float) toMin;
- (BOOL) stretchToMax;
- (BOOL) stretchToMin;
- (int) xScale;
- (int) format;
- (int) setToCount;
- (float *) reals;
- (int) realsSize;
- (int) realsCount;
- (int) displayCount;
- (id) cursorX;
- (id) cursorY;
- (int) cursorCount;
@end

@implementation FakeFftGraph
- (void) dealloc
    {
    free (_reals);
    [_cursorX release];
    [_cursorY release];
    [super dealloc];
    }
- setTo:(float)maxVal:(float)minVal:(BOOL)stretchToMax:(BOOL)stretchToMin:
    (int)xScale:(int)format
    {
    _toMax = maxVal;
    _toMin = minVal;
    _stretchToMax = stretchToMax;
    _stretchToMin = stretchToMin;
    _xScale = xScale;
    _format = format;
    _setToCount++;
    return self;
    }
- setReals:(float*)r size:(int)s
    {
    free (_reals);
    _reals = (float*)malloc (sizeof (float) * s);
    memcpy (_reals, r, sizeof (float) * s);
    _realsSize = s;
    _realsCount++;
    return self;
    }
- (void) display
    {
    _displayCount++;
    }
- useCursor:x_d:y_d
    {
    if (_cursorX != x_d)
        {
        [_cursorX release];
        _cursorX = [x_d retain];
        }
    if (_cursorY != y_d)
        {
        [_cursorY release];
        _cursorY = [y_d retain];
        }
    _cursorCount++;
    return self;
    }
- (float) toMax { return _toMax; }
- (float) toMin { return _toMin; }
- (BOOL) stretchToMax { return _stretchToMax; }
- (BOOL) stretchToMin { return _stretchToMin; }
- (int) xScale { return _xScale; }
- (int) format { return _format; }
- (int) setToCount { return _setToCount; }
- (float *) reals { return _reals; }
- (int) realsSize { return _realsSize; }
- (int) realsCount { return _realsCount; }
- (int) displayCount { return _displayCount; }
- (id) cursorX { return _cursorX; }
- (id) cursorY { return _cursorY; }
- (int) cursorCount { return _cursorCount; }
@end

/*
A stand-in for the FFT panel's minimum-dB field: the gorm types
it as a text field, whose cell answers setFloatValue: /
floatValue: in float (the 1998 controller writes the computed
floor and reads it back for the decibel range).  It records both.
(Both in float, as the other value fakes: the AppKit cells'
setFloatValue: is float-typed, and an id receiver would trip
-Wobjc-multiple-method-names on a double twin.)
*/
@interface FakeFftField : NSObject
{
    float _value;
    int _setValueCount;
}
- (void) setFloatValue: (float)value;
- (float) floatValue;
- (int) setValueCount;
@end

@implementation FakeFftField
- (void) setFloatValue: (float)value
    {
    _value = value;
    _setValueCount++;
    }
- (float) floatValue
    {
    return _value;
    }
- (int) setValueCount
    {
    return _setValueCount;
    }
@end

/*
A stand-in for the FFT panel's decibel button (the gorm types it
as a button cell): the controller reads its intValue to flip the
linear/decibel mode, and the gorm's initial value is 1.
*/
@interface FakeFftButton : NSObject
{
    int _value;
}
- initWithValue: (int)value;
- (void) setIntValue: (int)value;
- (int) intValue;
@end

@implementation FakeFftButton
- initWithValue: (int)value
    {
    if (self = [super init])
        _value = value;
    return self;
    }
- (void) setIntValue: (int)value
    {
    _value = value;
    }
- (int) intValue
    {
    return _value;
    }
@end

/*
A stand-in for the FFT panel window and its two axis fields: the
1998 showFFTPanel: orders the panel key and front and hands the
two axis fields to the controller's setDelegates: (which forwards
them to the frequency graph's cursor).  The panel records the
order-front; the axis fields are bare identities.
*/
@interface FakeFftPanel : NSObject
{
    int _keyFront;
}
- (void) makeKeyAndOrderFront: (id)sender;
- (int) keyFrontCount;
@end

@implementation FakeFftPanel
- (void) makeKeyAndOrderFront: (id)sender
    {
    _keyFront++;
    }
- (int) keyFrontCount
    {
    return _keyFront;
    }
@end

@interface FakeFftAxis : NSObject
@end

@implementation FakeFftAxis
@end

/*
A stand-in for the app's ModuleController for the FFT contract:
the 1998 doFFT: reads currentSound / currentSoundView, so this
answers both - with the real in-memory Snd and the real SndView
the case builds - and nothing else is recorded (the module's only
other dependency is the fftController ivar, which the contract
sets to the bundle's real FFTController).
*/
@interface FakeFftController : NSObject
{
    Snd *_sound;
    id _soundView;
}
- (id) initWithSound: (Snd *)sound soundView: (id)soundView;
- (id) currentSound;
- (id) currentSoundView;
@end

@implementation FakeFftController
- (id) initWithSound: (Snd *)sound soundView: (id)soundView
    {
    if (self = [super init])
        {
        _sound = [sound retain];
        _soundView = [soundView retain];
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
@end

/*
The Math contract's stand-ins for the two lazy gorm panels and the
module's panel controls:

  - FakeMathPanel counts makeKeyAndOrderFront: calls - the one
    AppKit message showMultiplyPanel: / showShiftPanel: send to the
    panel after the (skipped) nib load.
  - FakeMathField mirrors the gorm's percent text field: the module
    reads it with floatValue: (multiplyIt:) and writes it with
    setIntValue: (halve: / double:) and setFloatValue:
    (maximize:) - the two value pairs the 1998 NSTextField
    provides, and the last written of the two wins on read.
  - FakeMathScroller mirrors the gorm's percent slider (the same
    value pairs; the module only writes it).
  - FakeMathSlider mirrors the gorm's shift slider (the module only
    reads its floatValue: in shiftIt:).

The field and the scroller start at the gorm's value (100, the
number formatter's default).
*/
@interface FakeMathPanel : NSObject
{
    int _keyFront;
}
- (void) makeKeyAndOrderFront: (id)sender;
- (int) keyFrontCount;
@end

@implementation FakeMathPanel
- (void) makeKeyAndOrderFront: (id)sender
    {
    _keyFront++;
    }
- (int) keyFrontCount
    {
    return _keyFront;
    }
@end

@interface FakeMathField : NSObject
{
    float _float;
    int _int;
}
- (id) initWithFloatValue: (float)value;
- (float) floatValue;
- (void) setFloatValue: (float)value;
- (int) intValue;
- (void) setIntValue: (int)value;
@end

@implementation FakeMathField
- (id) initWithFloatValue: (float)value
    {
    if (self = [super init])
        {
        _float = value;
        _int = (int)value;
        }
    return self;
    }
- (float) floatValue
    {
    return _float;
    }
- (void) setFloatValue: (float)value
    {
    _float = value;
    _int = (int)value;
    }
- (int) intValue
    {
    return _int;
    }
- (void) setIntValue: (int)value
    {
    _int = value;
    _float = (float)value;
    }
@end

@interface FakeMathScroller : NSObject
{
    float _float;
    int _int;
}
- (id) initWithFloatValue: (float)value;
- (float) floatValue;
- (void) setFloatValue: (float)value;
- (int) intValue;
- (void) setIntValue: (int)value;
@end

@implementation FakeMathScroller
- (id) initWithFloatValue: (float)value
    {
    if (self = [super init])
        {
        _float = value;
        _int = (int)value;
        }
    return self;
    }
- (float) floatValue
    {
    return _float;
    }
- (void) setFloatValue: (float)value
    {
    _float = value;
    _int = (int)value;
    }
- (int) intValue
    {
    return _int;
    }
- (void) setIntValue: (int)value
    {
    _int = value;
    _float = (float)value;
    }
@end

@interface FakeMathSlider : NSObject
{
    float _float;
}
- (id) initWithFloatValue: (float)value;
- (float) floatValue;
- (void) setFloatValue: (float)value;
@end

@implementation FakeMathSlider
- (id) initWithFloatValue: (float)value
    {
    if (self = [super init])
        _float = value;
    return self;
    }
- (float) floatValue
    {
    return _float;
    }
- (void) setFloatValue: (float)value
    {
    _float = value;
    }
@end

/*
A stand-in for the app's current sound view for the Math contract:
the 1998 flow touches only getSelection:size: (a zero length
falls through to the whole sound in the module) and
checkForCurrentDataOnPasteboard (the app's ModuleSoundView
category clears a stale pasteboard; a no-op here), so a plain
NSObject with the family's fake-view shape is exact.
*/
@interface FakeMathView : NSObject
{
    Snd *_sound;
    unsigned int _first;
    unsigned int _len;
}
- (id) initWithSound: (Snd *)sound;
- (void) setSelection: (unsigned int)first size: (unsigned int)len;
- (void) getSelection: (unsigned int *)firstSample size: (unsigned int *)sampleLength;
- (void) checkForCurrentDataOnPasteboard;
@end

@implementation FakeMathView
- (id) initWithSound: (Snd *)sound
    {
    if (self = [super init])
        {
        _sound = [sound retain];
        _first = 0;
        _len = (unsigned int)[_sound lengthInSampleFrames];
        }
    return self;
    }
- (void) dealloc
    {
    [_sound release];
    [super dealloc];
    }
- (void) setSelection: (unsigned int)first size: (unsigned int)len
    {
    _first = first;
    _len = len;
    }
- (void) getSelection: (unsigned int *)firstSample size: (unsigned int *)sampleLength
    {
    *firstSample = _first;
    *sampleLength = _len;
    }
- (void) checkForCurrentDataOnPasteboard
    {
    /* The app's ModuleSoundView category clears a stale pasteboard; a no-op here. */
    }
@end

/*
A stand-in for the app's ModuleController for the Math contract:
the six DSP actions read currentSound / currentSoundView and
record the two side effects (stop, soundChanged).
*/
@interface FakeMathController : NSObject
{
    Snd *_sound;
    id _soundView;
    int _stopped;
    int _soundChanged;
}
- (id) initWithSound: (Snd *)sound soundView: (id)soundView;
- (id) currentSound;
- (id) currentSoundView;
- (void) stop;
- (void) soundChanged;
- (int) stopCount;
- (int) soundChangedCount;
@end

@implementation FakeMathController
- (id) initWithSound: (Snd *)sound soundView: (id)soundView
    {
    if (self = [super init])
        {
        _sound = [sound retain];
        _soundView = [soundView retain];
        _stopped = 0;
        _soundChanged = 0;
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
    _stopped++;
    }
- (void) soundChanged
    {
    _soundChanged++;
    }
- (int) stopCount
    {
    return _stopped;
    }
- (int) soundChangedCount
    {
    return _soundChanged;
    }
@end

/*
A stand-in for the app's ResoundMiscSoundView for the Channel
contract: the five actions touch only getSelection:size: (a zero
length falls through to the whole sound in the module),
checkForCurrentDataOnPasteboard (the app's ModuleSoundView
category clears a stale pasteboard; a no-op here), and setSound:
(the strip/add pair hand the freshly built sound to the view) -
a plain NSObject with the family's fake-view shape is exact.
*/
@interface FakeChannelView : NSObject
{
    Snd *_sound;
    unsigned int _first;
    unsigned int _len;
}
- (id) initWithSound: (Snd *)sound;
- (void) setSelection: (unsigned int)first size: (unsigned int)len;
- (void) getSelection: (unsigned int *)firstSample size: (unsigned int *)sampleLength;
- (void) checkForCurrentDataOnPasteboard;
- (void) setSound: (Snd *)sound;
- (id) sound;
@end

@implementation FakeChannelView
- (id) initWithSound: (Snd *)sound
    {
    if (self = [super init])
        {
        _sound = [sound retain];
        _first = 0;
        _len = (unsigned int)[_sound lengthInSampleFrames];
        }
    return self;
    }
- (void) dealloc
    {
    [_sound release];
    [super dealloc];
    }
- (void) setSelection: (unsigned int)first size: (unsigned int)len
    {
    _first = first;
    _len = len;
    }
- (void) getSelection: (unsigned int *)firstSample size: (unsigned int *)sampleLength
    {
    *firstSample = _first;
    *sampleLength = _len;
    }
- (void) checkForCurrentDataOnPasteboard
    {
    /* The app's ModuleSoundView category clears a stale pasteboard; a no-op here. */
    }
- (void) setSound: (Snd *)sound
    {
    if (_sound != sound)
        {
        [_sound release];
        _sound = [sound retain];
        }
    }
- (id) sound
    {
    return _sound;
    }
@end

/*
A stand-in for the app's ModuleController for the Channel
contract: the five actions read currentSound / currentSoundView
and record the three side effects (stop, soundChanged, and the
strip/add pair's newSound:for: hand-off, which also swaps the
controller's current sound to the freshly built one, as the
app's does).
*/
@interface FakeChannelController : NSObject
{
    Snd *_sound;
    id _soundView;
    int _stopped;
    int _soundChanged;
    int _newSound;
}
- (id) initWithSound: (Snd *)sound soundView: (id)soundView;
- (id) currentSound;
- (id) currentSoundView;
- (void) stop;
- (void) soundChanged;
- (id) newSound: (id)newSound for: (id)view;
- (int) stopCount;
- (int) soundChangedCount;
- (int) newSoundCount;
@end

@implementation FakeChannelController
- (id) initWithSound: (Snd *)sound soundView: (id)soundView
    {
    if (self = [super init])
        {
        _sound = [sound retain];
        _soundView = [soundView retain];
        _stopped = 0;
        _soundChanged = 0;
        _newSound = 0;
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
    _stopped++;
    }
- (void) soundChanged
    {
    _soundChanged++;
    }
- (id) newSound: (id)newSound for: (id)view
    {
    _newSound++;
    if (_sound != newSound)
        {
        [_sound release];
        _sound = [newSound retain];
        }
    return self;
    }
- (int) stopCount
    {
    return _stopped;
    }
- (int) soundChangedCount
    {
    return _soundChanged;
    }
- (int) newSoundCount
    {
    return _newSound;
    }
@end

/*
The five waveform functions the 1998 module carries -
byte-identical copies, the way the other contracts mirror the
module's own arithmetic to compute the expected buffer.  The
operator-precedence quirks (the % binding tighter than the * in
the sawtooth / square / triangle range tests, and the 1998
"okay, don't mock it; it works" note on the triangle's last
branch) are part of the expectation.  The noise is the only
non-pure one: rand() is deterministic under a fixed seed, so the
contract seeds, runs the module (which consumes the sequence),
re-seeds, and regenerates the same values for the expectation.
The RAND_MAX division is the 1998 fingerprint the module's copy
documents (2^31-1 does not fit a float, so it converts to
2^31) - the same rounding, which modern clang points out with
-Wimplicit-const-int-float-conversion.
*/
static float wbPulse (int position, int wavelength)
    {
    if (position%wavelength==0)    return 1.0;
    if ((position-1)%wavelength==0) return -1.0;
    return 0.0;
    }

static float wbSawtooth (int position, int wavelength)
    {
    if (position%wavelength*2<wavelength)         // positive rise
        {
        return (
            ((float)(position%wavelength))*2/wavelength);
        }
    else                                        // negative rise
        {
        return (
            ((float)(position%wavelength-(wavelength/2)))*2/wavelength)-1;
        }
    }

static float wbNoise (int position, int wavelength)
    {
    return 2*((float)rand())/RAND_MAX-1;
    }

static float wbSquare (int position, int wavelength)
    {
    if (position%wavelength*2>wavelength)
        {
        return -1.0;
        }
    return 1.0;
    }

static float wbTriangle (int position, int wavelength)
    {
    if (position%wavelength*4<wavelength)         // positive rise
        {
        return (
            ((float)(position%wavelength))*4/wavelength);
        }
    else if (position%wavelength*2<wavelength)    // positive fall
        {
        return 1-(
            ((float)(position%wavelength)-(wavelength/4))*4/wavelength);
        }
    else if ((position%wavelength*4)<wavelength*3) // negative fall
        {
        return 0-(
            ((float)(position%wavelength)-(wavelength/2))*4/wavelength);
        }
    else                                        // negative rise
        {
        return (
            (((float)(position%wavelength)/(float)(wavelength))-.75)*4)
            -1;
            // okay, don't mock it; it works.
        }
    }

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
The gate test pattern: a silent lead-in (frames 0..99), a loud
run (100..599) and a quiet tail (600 up) - per interleaved
sample, in the sound's own stored format.  The three levels sit
against the module's threshold compare (half of the format's
full scale, for the 50/100 panel float) the way the gate is
meant to see them, on any platform: the 8-bit loud level is
byte 0x80, which the module's char read takes as +128 on a
char-unsigned platform (abs 128, at or above its 127.5
threshold) and as -128 on a signed-char platform (abs 128,
at or above its 63.5 threshold) - the one 8-bit value loud
under either char signedness; the quiet and silent levels are
small non-negative values, below the threshold under either
(the 8-bit full scale is CHAR_MAX - 255 on a char-unsigned
platform, 127 on a signed one; see the module's note on its
abs()/CHAR_MAX fingerprint).  For mu-law the levels are the
G.711 codes for the same roles: the standard silence code
(0xFF - the 1998 Zero comment's guess of 127 is the loudest
mu-law byte, not silence) for the lead-in, a near-full-scale
code for the loud run, and a small code for the quiet tail.
*/
static void gateFill (Snd *snd)
{
    long frames = (long)[snd lengthInSampleFrames];
    int ch = [snd channelCount];
    void *bytes = [snd bytes];
    long n;
    for (n = 0; n < frames * ch; n++)
    {
        long frame = n / ch;
        int region = frame < 100 ? 0 : frame < 600 ? 1 : 2;
        switch ([snd dataFormat])
        {
        case SND_FORMAT_MULAW_8:
            ((unsigned char *)bytes)[n] = region == 0 ? (unsigned char)SndLinearToMuLaw (0)
                                        : region == 1 ? (unsigned char)SndLinearToMuLaw (32000)
                                        : (unsigned char)SndLinearToMuLaw (500);
            break;
        case SND_FORMAT_LINEAR_8:
            ((char *)bytes)[n] = (char)(region == 0 ? 0 : region == 1 ? 128 : 4);
            break;
        case SND_FORMAT_LINEAR_16:
            ((short *)bytes)[n] = (short)(region == 0 ? 0 : region == 1 ? 32000 : 1000);
            break;
        case SND_FORMAT_FLOAT:
            ((float *)bytes)[n] = region == 0 ? 0.0f : region == 1 ? 1.5f : 0.4f;
            break;
        case SND_FORMAT_DOUBLE:
            ((double *)bytes)[n] = region == 0 ? 0.0 : region == 1 ? 1.5 : 0.4;
            break;
        default:
            break;
        }
    }
}

/*
Read one interleaved sample (frame, channel) of the sound's
own format into dst.
*/
static void gateReadSample (const unsigned char *bytes, long frame,
                            int channel, int ch, int bps,
                            unsigned char *dst)
{
    memcpy (dst, bytes + (frame * ch + channel) * bps, (size_t)bps);
}

/*
The linear value the gate's threshold compare sees for a
stored sample: the format's own number, mu-law decoded through
SndKit's table (in the mu-law case the module compares the
decoded linear value).  The semantic spot checks read the
gated buffer through this, so they test behaviour (loud /
quiet / silent) rather than the exact stored code - which for
mu-law the module rewrites through a decode/encode round trip
on every write-back.
*/
static double gateSampleValue (SndSampleFormat fmt,
                               const unsigned char *sample, int bps)
{
    switch (fmt)
    {
    case SND_FORMAT_MULAW_8:
        return SndMuLawToLinear (sample[0]);
    case SND_FORMAT_LINEAR_8:
        return (int)(char)sample[0];
    case SND_FORMAT_LINEAR_16:
        {
        short v;
        memcpy (&v, sample, (size_t)bps);
        return v;
        }
    case SND_FORMAT_FLOAT:
        {
        float v;
        memcpy (&v, sample, (size_t)bps);
        return v;
        }
    case SND_FORMAT_DOUBLE:
        {
        double v;
        memcpy (&v, sample, (size_t)bps);
        return v;
        }
    default:
        return 0;
    }
}

/* The module's abs(tempsnd), as the module computes it: for the
   float formats the 1998 int truncation, for the integer formats
   an exact magnitude - so the zone checks below compare the same
   value the module's threshold compare sees, on any platform. */
static double gateAbsValue (double v)
{
    int i = (int)v;
    return i < 0 ? -(double)i : (double)i;
}

/* The format's full scale, the module's per-case hi_clip. */
static double gateHiClip (SndSampleFormat fmt)
{
    switch (fmt)
    {
    case SND_FORMAT_MULAW_8:
    case SND_FORMAT_LINEAR_16:
        return SHRT_MAX;
    case SND_FORMAT_LINEAR_8:
        return CHAR_MAX;
    case SND_FORMAT_FLOAT:
    case SND_FORMAT_DOUBLE:
        return 1.0;
    default:
        return 1.0;
    }
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

/*
The 1998 Envelope fade, sample by sample: each sample of the
selection is multiplied by a multiplier between 0.0 and 1.0 (rising
for a fade in, falling for a fade out, the 1998 changeFactor math),
per channel, in the sound's own format.  The per-format expressions
are the module's own (mu-law through the same SndKit conversion
pair - the decode maxes out at 32124 and the multiplier is <= 1.0,
so no clip, as in the port), so the expected buffer equals the
module's arithmetic exactly.
*/
static void dspFade (unsigned char *buf, const unsigned char *orig,
                     unsigned long first, unsigned long len, int ch,
                     BOOL fadeIn, int applyToChannel[2], SndSampleFormat fmt)
{
    double changeFactor = 1.0 / (double)len;
    unsigned long sample;
    for (sample = first; sample < first + len; sample++)
    {
        long index = (long)sample * ch;
        double sampleMultiplier = fadeIn
            ? ((sample - first) * changeFactor)
            : (1.0 - ((sample - first) * changeFactor));
        int channel;
        for (channel = 0; channel < ch; channel++)
        {
            if (!applyToChannel[channel])
                continue;
            switch (fmt)
            {
            case SND_FORMAT_LINEAR_8:
                ((char *)buf)[index + channel] =
                    ((char *)orig)[index + channel] * sampleMultiplier;
                break;
            case SND_FORMAT_MULAW_8:
                buf[index + channel] = SndLinearToMuLaw
                    ((short)(SndMuLawToLinear ((unsigned char)orig[index + channel])
                                * sampleMultiplier));
                break;
            case SND_FORMAT_LINEAR_16:
                ((short *)buf)[index + channel] =
                    ((short *)orig)[index + channel] * sampleMultiplier;
                break;
            case SND_FORMAT_FLOAT:
                ((float *)buf)[index + channel] =
                    ((float *)orig)[index + channel] * sampleMultiplier;
                break;
            case SND_FORMAT_DOUBLE:
                ((double *)buf)[index + channel] =
                    ((double *)orig)[index + channel] * sampleMultiplier;
                break;
            default:
                break;
            }
        }
    }
}

/*
The 1998 Gate DSP, sample by sample: the per-channel noise gate
state machine of the module's switch, run on the caller's copy of
the pre-gate buffer.  The module edits in place, but it reads and
writes each interleaved sample exactly once, so the copy sees the
same values; the per-format expressions mirror the module's line
for line (mu-law decodes and re-encodes through SndKit's same
conversion pair, the multiplier is between 0.0 and 1.0 so the
product only shrinks - no clip, as in the port).  The one
deviation: the module's abs(tempsnd) threshold compares go through
gateAbs - the same standard integer abs, the same argument
conversion at the call (for the float formats that is the 1998
truncation quirk the module preserves, for the 8-bit format it
takes the platform's char sign - the pattern keeps the two sides
in agreement on any platform) - so that the six 1998 warnings
the raw calls carry stay in the module's own build and out of
this shared translation unit.
*/
#define GATE_STATE_APPLIED 1
#define GATE_STATE_RELEASED 0

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wabsolute-value"
static int gateAbs (int v)
{
    return abs (v);
}
#pragma clang diagnostic pop

static void gateExpected (unsigned char *buf, unsigned int first,
                          unsigned int len, int ch, float threshold,
                          int swait, int scut, SndSampleFormat fmt)
{
    switch (fmt)
    {
    case SND_FORMAT_MULAW_8:
        {
        signed short tempsnd;
        char *d = (char *)buf;
        signed short hi_clip = SHRT_MAX;
        int x;
        int y;

        for (y = 0; y < ch; y++)
            {
            int gateState = GATE_STATE_RELEASED;
            int gateCount = 0;

            for (x = first * ch + y;
                 x < (first + len) * ch;
                 x += ch)
                {
                tempsnd = SndMuLawToLinear ((unsigned char)d[x]);
                if (gateState == GATE_STATE_RELEASED)
                    {
                    if (gateAbs (tempsnd) < hi_clip * threshold) gateCount++;
                    if (gateCount > swait)
                        {
                        gateCount = 0;
                        gateState = GATE_STATE_APPLIED;
                        }
                    }
                else
                    {
                    if (gateAbs (tempsnd) >= hi_clip * threshold)
                        {
                        gateCount = 0;
                        gateState = GATE_STATE_RELEASED;
                        }
                    else
                        {
                        tempsnd *= (gateCount >= scut ? 0 : (1.0 - ((float)gateCount / (float)scut)));
                        gateCount++;
                        }
                    }
                d[x] = SndLinearToMuLaw (tempsnd);
                }
            }
        }
        break;
    case SND_FORMAT_LINEAR_8:
        {
        char tempsnd;
        char *d = (char *)buf;
        char hi_clip = CHAR_MAX;
        int x;
        int y;

        for (y = 0; y < ch; y++)
            {
            int gateState = GATE_STATE_RELEASED;
            int gateCount = 0;

            for (x = first * ch + y;
                 x < (first + len) * ch;
                 x += ch)
                {
                tempsnd = (d[x]);
                if (gateState == GATE_STATE_RELEASED)
                    {
                    if (gateAbs (tempsnd) < hi_clip * threshold) gateCount++;
                    if (gateCount > swait)
                        {
                        gateCount = 0;
                        gateState = GATE_STATE_APPLIED;
                        }
                    }
                else
                    {
                    if (gateAbs (tempsnd) >= hi_clip * threshold)
                        {
                        gateCount = 0;
                        gateState = GATE_STATE_RELEASED;
                        }
                    else
                        {
                        tempsnd *= (gateCount >= scut ? 0 : (1.0 - ((float)gateCount / (float)scut)));
                        gateCount++;
                        }
                    }
                d[x] = (tempsnd);
                }
            }
        }
        break;
    case SND_FORMAT_LINEAR_16:
        {
        signed short tempsnd;
        signed short *d = (signed short *)buf;
        signed short hi_clip = SHRT_MAX;
        int x;
        int y;

        for (y = 0; y < ch; y++)
            {
            int gateState = GATE_STATE_RELEASED;
            int gateCount = 0;

            for (x = first * ch + y;
                 x < (first + len) * ch;
                 x += ch)
                {
                tempsnd = (d[x]);
                if (gateState == GATE_STATE_RELEASED)
                    {
                    if (gateAbs (tempsnd) < hi_clip * threshold) gateCount++;
                    if (gateCount > swait)
                        {
                        gateCount = 0;
                        gateState = GATE_STATE_APPLIED;
                        }
                    }
                else
                    {
                    if (gateAbs (tempsnd) >= hi_clip * threshold)
                        {
                        gateCount = 0;
                        gateState = GATE_STATE_RELEASED;
                        }
                    else
                        {
                        tempsnd *= (gateCount >= scut ? 0 : (1.0 - ((float)gateCount / (float)scut)));
                        gateCount++;
                        }
                    }
                d[x] = (tempsnd);
                }
            }
        }
        break;
    case SND_FORMAT_FLOAT:
        {
        float tempsnd;
        float *d = (float *)buf;
        float hi_clip = 1.0;
        int x;
        int y;

        for (y = 0; y < ch; y++)
            {
            int gateState = GATE_STATE_RELEASED;
            int gateCount = 0;

            for (x = first * ch + y;
                 x < (first + len) * ch;
                 x += ch)
                {
                tempsnd = (d[x]);
                if (gateState == GATE_STATE_RELEASED)
                    {
                    if (gateAbs (tempsnd) < hi_clip * threshold) gateCount++;
                    if (gateCount > swait)
                        {
                        gateCount = 0;
                        gateState = GATE_STATE_APPLIED;
                        }
                    }
                else
                    {
                    if (gateAbs (tempsnd) >= hi_clip * threshold)
                        {
                        gateCount = 0;
                        gateState = GATE_STATE_RELEASED;
                        }
                    else
                        {
                        tempsnd *= (gateCount >= scut ? 0 : (1.0 - ((float)gateCount / (float)scut)));
                        gateCount++;
                        }
                    }
                d[x] = (tempsnd);
                }
            }
        }
        break;
    case SND_FORMAT_DOUBLE:
        {
        double tempsnd;
        double *d = (double *)buf;
        double hi_clip = 1.0;
        int x;
        int y;

        for (y = 0; y < ch; y++)
            {
            int gateState = GATE_STATE_RELEASED;
            int gateCount = 0;

            for (x = first * ch + y;
                 x < (first + len) * ch;
                 x += ch)
                {
                tempsnd = (d[x]);
                if (gateState == GATE_STATE_RELEASED)
                    {
                    if (gateAbs (tempsnd) < hi_clip * threshold) gateCount++;
                    if (gateCount > swait)
                        {
                        gateCount = 0;
                        gateState = GATE_STATE_APPLIED;
                        }
                    }
                else
                    {
                    if (gateAbs (tempsnd) >= hi_clip * threshold)
                        {
                        gateCount = 0;
                        gateState = GATE_STATE_RELEASED;
                        }
                    else
                        {
                        tempsnd *= (gateCount >= scut ? 0 : (1.0 - ((float)gateCount / (float)scut)));
                        gateCount++;
                        }
                    }
                d[x] = (tempsnd);
                }
            }
        }
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

/*
Inject the Envelope contract's stand-ins into the module's private
ivars: the controller (inherited from Module, the app's own wiring
runs setModuleControllerTo: and its conformance check a duck-typed
double fails) and the six panel outlets (the app wires them from the
gorm panel when it loads; the fakes stand in for whatever that
wiring would have provided - pre-setting the panel is what makes the
module skip the nib load the contract drives around).
*/
static void injectEnvelopeFakes (id module, Ivar controllerIvar,
                                 id panel, id apply, id matrix,
                                 id left, id right, id all,
                                 FakeEnvelopeController *controller)
{
    object_setIvar (module, controllerIvar, controller);
    object_setIvar (module, class_getInstanceVariable ([module class], "envelopePanel"), panel);
    object_setIvar (module, class_getInstanceVariable ([module class], "applyButton"), apply);
    object_setIvar (module, class_getInstanceVariable ([module class], "inOutMatrix"), matrix);
    object_setIvar (module, class_getInstanceVariable ([module class], "applyToLeftButton"), left);
    object_setIvar (module, class_getInstanceVariable ([module class], "applyToRightButton"), right);
    object_setIvar (module, class_getInstanceVariable ([module class], "applyToAllButton"), all);
}

/*
The showEnvelopePanel: contract: with the panel outlets pre-set to
the fakes, the nib load the module performs for a missing panel is
skipped (a real load needs a display - the app-side half is the
resoundmenu --perform probe, where the panel comes up for real).
What the 1998 method then does must show up on the fakes: the three
channel buttons come up selected, the enabled states follow the
sound's channel count and the current window, and the panel is
ordered front.  (The 1998 nib leaves applyToAllButton unconnected,
so the app's button stays nil and silently drops the setState:; the
gate's fake receives it.  The apply button's state is the gorm's
initial value - the module must not touch it.)
*/
static void testShowEnvelopePanel (id module, Ivar ivar, int channels)
{
    printf ("== showEnvelopePanel: with a %d channel document\n", channels);
    BOOL stereo = channels > 1;

    Snd *snd = [[[Snd alloc] initWithFormat: SND_FORMAT_LINEAR_16
                                channelCount: channels
                                    frames: 200
                              samplingRate: 44100.0f] autorelease];
    if (snd == nil)
    {
        check (NO, "Snd construction");
        return;
    }
    FakeEnvelopeView *view =
        [[[FakeEnvelopeView alloc] initWithSound: snd] autorelease];
    id window = [[[NSObject alloc] init] autorelease];    /* a current window */
    FakeEnvelopeController *controller =
        [[[FakeEnvelopeController alloc] initWithSound: snd soundView: view window: window] autorelease];

    FakeEnvelopePanel *panel =
        [[[FakeEnvelopePanel alloc] init] autorelease];
    FakeEnvelopeButton *apply =
        [[[FakeEnvelopeButton alloc] init] autorelease];
    FakeEnvelopeMatrix *matrix =
        [[[FakeEnvelopeMatrix alloc] init] autorelease];
    FakeEnvelopeButton *left =
        [[[FakeEnvelopeButton alloc] init] autorelease];
    FakeEnvelopeButton *right =
        [[[FakeEnvelopeButton alloc] init] autorelease];
    FakeEnvelopeButton *all =
        [[[FakeEnvelopeButton alloc] init] autorelease];
    injectEnvelopeFakes (module, ivar, panel, apply, matrix, left, right, all, controller);

    id ret = [(EnvelopeModule *)module showEnvelopePanel: nil];

    check (ret == module, "showEnvelopePanel: returns self");
    check ([panel orderFrontCount] == 1, "the panel was ordered front");
    check ([left state] == 1, "left-channel button comes up selected");
    check ([right state] == 1, "right-channel button comes up selected");
    check ([all state] == 1, "all-channels button comes up selected");
    check ([apply state] == 0, "the apply button's state is left alone");
    check ([apply enabled] == YES, "the apply button is enabled (a current window)");
    check ([left enabled] == stereo, "channel buttons follow the channel count");
    check ([right enabled] == stereo, "channel buttons follow the channel count (2)");
    check ([all enabled] == stereo, "channel buttons follow the channel count (3)");
}

/*
The applyEnvelope: DSP contract: a (first, len) selection on a
frames-frame sound, faded in (tag 0) or out (tag 1), on the channels
the button states select.  The expected sound is the pre-fade sound
with the 1998 fade applied - the module's own per-format multiply
arithmetic (see dspFade) - and everything outside the selection must
stay byte-identical.  The all button carries the state the app's
panel would have: 0 (the 1998 nib never connected it).
*/
static void testEnvelope (id module, Ivar ivar, SndSampleFormat fmt, int ch,
                          BOOL fadeIn, unsigned long first, unsigned long len,
                          int leftState, int rightState, unsigned long frames)
{
    const char *name = [SndFormatName (fmt, NO) cStringUsingEncoding: NSASCIIStringEncoding];
    printf ("== applyEnvelope: %s, %d channel(s), fade %s, selection (%lu,%lu) on a %lu-frame sound\n",
            name, ch, fadeIn ? "in" : "out",
            (unsigned long)first, (unsigned long)len, (unsigned long)frames);

    Snd *snd = [[[Snd alloc] initWithFormat: fmt
                                channelCount: ch
                                    frames: frames
                              samplingRate: 44100.0f] autorelease];
    if (snd == nil || [snd lengthInSampleFrames] != frames)
    {
        check (NO, "Snd construction");
        return;
    }
    fillPattern (snd, 1);

    FakeEnvelopeView *view =
        [[[FakeEnvelopeView alloc] initWithSound: snd] autorelease];
    [view setSelection: first size: len];
    id window = [[[NSObject alloc] init] autorelease];
    FakeEnvelopeController *controller =
        [[[FakeEnvelopeController alloc] initWithSound: snd soundView: view window: window] autorelease];

    FakeEnvelopePanel *panel =
        [[[FakeEnvelopePanel alloc] init] autorelease];
    FakeEnvelopeButton *apply =
        [[[FakeEnvelopeButton alloc] init] autorelease];
    FakeEnvelopeMatrix *matrix =
        [[[FakeEnvelopeMatrix alloc] init] autorelease];
    [[matrix selectedCell] setTag: fadeIn ? 0 : 1];
    FakeEnvelopeButton *left =
        [[[FakeEnvelopeButton alloc] init] autorelease];
    [left setState: leftState];
    FakeEnvelopeButton *right =
        [[[FakeEnvelopeButton alloc] init] autorelease];
    [right setState: rightState];
    FakeEnvelopeButton *all =
        [[[FakeEnvelopeButton alloc] init] autorelease];    /* 0, as in the app */
    injectEnvelopeFakes (module, ivar, panel, apply, matrix, left, right, all, controller);

    long size = [snd dataSize];
    unsigned char *before = malloc ((size_t)size);
    memcpy (before, [snd bytes], (size_t)size);

    id ret = [(EnvelopeModule *)module applyEnvelope: nil];

    check (ret == module, "applyEnvelope: returns self");
    check ([controller stoppedCount] == 1, "applyEnvelope: stopped playback first");
    check ([controller soundChangedCount] == 1, "applyEnvelope: reported the sound changed");
    int expectLongTime = len > 400000UL * (unsigned long)ch ? 1 : 0;
    check ([controller longTimeCount] == expectLongTime,
           expectLongTime ? "runLongTimePanel consulted for the long sound"
                          : "runLongTimePanel skipped for the short sound");

    /* The per-channel selection the button states imply, the way the
       1998 code derives it (the all button is 0 in every case). */
    int applyToChannel[2];
    applyToChannel[0] = leftState != 0;
    applyToChannel[1] = rightState != 0;

    /* As in the mix contract, the sample counts become byte offsets
       with the format's bytes-per-sample. */
    int bps = (fmt == SND_FORMAT_LINEAR_16 ? 2
             : fmt == SND_FORMAT_FLOAT ? 4
             : fmt == SND_FORMAT_DOUBLE ? 8 : 1);
    long off = (long)first * ch * bps;
    long rangeBytes = (long)len * ch * bps;

    unsigned char *expected = malloc ((size_t)size);
    memcpy (expected, before, (size_t)size);
    dspFade (expected, before, first, len, ch, fadeIn, applyToChannel, fmt);

    check (memcmp ([snd bytes] + off, expected + off, (size_t)rangeBytes) == 0,
           "faded range matches the 1998 DSP arithmetic");
    check (memcmp ([snd bytes], expected, (size_t)size) == 0,
           "the rest of the sound is untouched");
    free (before);
    free (expected);
}

/*
The 1998 EchoChamber DSP, sample by sample, on a scratch pair of
buffers: live[] tracks the module's in-place edit of the original
buffer (its addvalue read at x-delaycount sees the already-echoed
value, exactly as the module's does), expected[] is what the fresh
sound must end up (sample 0 zero - the 1998 loop starts at x=1, and
SndKit's fresh buffer is zero-initialized).  The casts mirror the
module's arithmetic line for line.
*/
static void echoExpected (short *live, short *expected, long frames,
                          int delaycount, int bigdelay,
                          float dropoff, float initial, float ratio)
{
    int a = 0;
    int b = 0;
    short addvalue = 0;
    long x;
    /* x < frames, as in the port: the 1998 loop's <= ran one
       sample past the end of the buffers (see the module's note). */
    for (x = 1; x < frames; x++)
    {
        expected[x] = live[x];
        if (++a > delaycount)
            addvalue = (short)((float)addvalue*dropoff
                              + (float)live[x-delaycount]*initial);
        live[x] += addvalue;
        if (++b > bigdelay)
            expected[x] += (short)((float)live[x]*ratio);
    }
}

/*
The performEcho: DSP contract on a conforming sound (mono, 16-bit
linear, 44.1k - the only shape the 1998 method accepts without its
modal NSRunAlertPanel conversion prompt, which the headless gate does
not exercise): the buffer must come out byte-identical to the 1998
arithmetic on the same input, the original buffer must carry the
in-place echo, and the hand-off (the view's setSound:, the
controller's newSound:for:) must deliver the freshly built sound.
*/
static void testEcho (id module, Ivar ivar,
                      float delay, float dropoff, float initial,
                      float firstDelay, float ratio, unsigned long frames)
{
    /* The 1998 constants, the way the module derives them. */
    int delaycount = (int)(delay*44100);
    int bigdelay = (int)(firstDelay*44100);

    printf ("== performEcho: 16-bit mono %lu frames (delaycount=%d, bigdelay=%d samples)\n",
            (unsigned long)frames, delaycount, bigdelay);

    /* The gate keeps its own reference: performEcho: releases the
       module-side one (the 1998 zone free, ported to release). */
    Snd *snd = [[Snd alloc] initWithFormat: SND_FORMAT_LINEAR_16
                             channelCount: 1
                                 frames: frames
                           samplingRate: 44100.0f];
    check (snd != nil && [snd lengthInSampleFrames] == frames, "Snd construction");
    if (snd == nil)
        return;
    fillPattern (snd, 1);
    [snd setInfo: @"echo-test"];

    FakeEchoView *view = [[[FakeEchoView alloc] init] autorelease];
    FakeEchoController *controller =
        [[[FakeEchoController alloc] initWithSound: snd soundView: view] autorelease];
    object_setIvar (module, ivar, controller);
    object_setIvar (module, class_getInstanceVariable ([module class], "delay"),
                    [[FakeEchoValue alloc] initWithValue: delay]);
    object_setIvar (module, class_getInstanceVariable ([module class], "dropoff"),
                    [[FakeEchoValue alloc] initWithValue: dropoff]);
    object_setIvar (module, class_getInstanceVariable ([module class], "initial"),
                    [[FakeEchoValue alloc] initWithValue: initial]);
    object_setIvar (module, class_getInstanceVariable ([module class], "firstDelay"),
                    [[FakeEchoValue alloc] initWithValue: firstDelay]);
    object_setIvar (module, class_getInstanceVariable ([module class], "ratio"),
                    [[FakeEchoValue alloc] initWithValue: ratio]);

    long size = [snd dataSize];
    short *before = malloc ((size_t)size);
    short *live = malloc ((size_t)size);
    short *expected = malloc ((size_t)size);
    memcpy (before, [snd bytes], (size_t)size);
    memcpy (live, before, (size_t)size);
    memset (expected, 0, (size_t)size);   /* a fresh Snd buffer is zero */
    echoExpected (live, expected, (long)frames, delaycount, bigdelay,
                  dropoff, initial, ratio);

    id ret = [(EchoChamber *)module performEcho: nil];

    check (ret == module, "performEcho: returns self");
    check ([controller newSoundCount] == 1, "the new sound was handed to the document");
    id newSound = [controller newSoundArg];
    Snd *newSnd = (Snd *)newSound;   /* typed: an untyped id would flag channelCount */
    check ([controller newSoundViewArg] == view, "the hand-off names the current view");
    check ([view setSoundCount] == 1, "the view was given the new sound");
    check ([view sound] == newSound, "view and document got the same new sound");
    check (newSnd != nil
       && [newSnd dataFormat] == SND_FORMAT_LINEAR_16
       && [newSnd channelCount] == 1
       && [newSnd lengthInSampleFrames] == frames
       && [newSnd samplingRate] == 44100.0
       && [[newSnd info] isEqualToString: @"echo-test"],
            "the new sound keeps the format, size and info string");
    check (memcmp ([newSnd bytes], expected, (size_t)size) == 0,
            "buffer matches the 1998 echo DSP byte-for-byte");
    check (memcmp ([snd bytes], live, (size_t)size) == 0,
            "the original buffer took the in-place echo");
    free (before);
    free (live);
    free (expected);
    [snd release];
}

/*
The gateIt: DSP contract: a (first, len) selection on a
1200-frame sound (len 0: the whole sound, the module's own
convention), over the five 1998 data formats.  The pattern is a
silent lead-in, a loud run and a quiet tail (gateFill): the
lead-in counts up the released state and ramps, the loud run
releases the gate and passes through untouched, and the quiet
tail ramps down - past the cut time it is gated to silence,
short of it it is attenuated but open.  The expected buffer is
the pre-gate sound with the module's own state machine applied
(gateExpected); everything outside the selection must stay
byte-identical, the controller's two side effects (stop before
the DSP, soundChanged after it) must land, and the samples must
sit in the zones the state machine implies - so a common
mistake in the module and its mirror could not hide behind the
byte-for-byte equality alone.  The three panel floats are the
50/0.002/0.01 the module's own math turns into the
88/440-sample state counts.
*/
static void testGate (id module, Ivar ivar, SndSampleFormat fmt, int ch,
                      unsigned int first, unsigned int len,
                      unsigned long frames)
{
    const char *name = [SndFormatName (fmt, NO) cStringUsingEncoding: NSASCIIStringEncoding];
    printf ("== gateIt: %s, %d channel(s), selection (%u,%u)%s on a %lu-frame sound\n",
            name, ch, first, len,
            len ? "" : " (a zero length is the whole sound)",
            (unsigned long)frames);

    Snd *snd = [[[Snd alloc] initWithFormat: fmt
                                channelCount: ch
                                    frames: frames
                              samplingRate: 44100.0f] autorelease];
    if (snd == nil || [snd lengthInSampleFrames] != frames
       || [snd channelCount] != ch || [snd dataFormat] != fmt)
    {
        check (NO, "Snd construction");
        return;
    }
    gateFill (snd);

    FakeGateView *view =
        [[[FakeGateView alloc] initWithSound: snd] autorelease];
    [view setSelection: first size: len];
    FakeGateController *controller =
        [[[FakeGateController alloc] initWithSound: snd soundView: view] autorelease];

    object_setIvar (module, ivar, controller);
    object_setIvar (module, class_getInstanceVariable ([module class], "thresholdField"),
                    [[FakeGateValue alloc] initWithValue: 50.0f]);
    object_setIvar (module, class_getInstanceVariable ([module class], "secondsWaitField"),
                    [[FakeGateValue alloc] initWithValue: 0.002f]);
    object_setIvar (module, class_getInstanceVariable ([module class], "secondsCutField"),
                    [[FakeGateValue alloc] initWithValue: 0.01f]);

    /* The module's own derivation of the state counts, from the
       same three panel floats and the sound's rate: the module
       clamps the floats first (no-ops for these values) before
       the int conversion - 0.002f * 44100 is 88.2, 0.01f
       falls just short of 441, as in the module. */
    float threshold = 50.0f / 100;
    float secondswait = 0.002f;
    float secondscut = 0.01f;
    if (threshold > 1) threshold = 1;
    if (threshold < 0) threshold = 0;
    if (secondswait < 0) secondswait = 0;
    if (secondscut < 0) secondscut = 0;
    int swait = secondswait * [snd samplingRate];
    int scut = secondscut * [snd samplingRate];
    check (swait == 88 && scut == 440,
            "the panel floats derive the 1998 state counts (88 wait, 440 cut)");

    /* The module's effective selection: a zero length is the
       whole sound, the module's own convention. */
    unsigned int firstEff = first;
    unsigned int lenEff = len;
    if (!lenEff)
    {
        firstEff = 0;
        lenEff = (unsigned int)[snd lengthInSampleFrames];
    }

    long size = [snd dataSize];
    unsigned char *before = malloc ((size_t)size);
    memcpy (before, [snd bytes], (size_t)size);

    id ret = [(GateModule *)module gateIt: nil];

    check (ret == module, "gateIt: returns self");
    check ([controller stoppedCount] == 1, "gateIt: stopped playback first");
    check ([controller soundChangedCount] == 1, "gateIt: reported the sound changed");

    /* As in the mix/envelope contracts, the sample counts
       become byte offsets with the format's bytes-per-sample. */
    int bps = (fmt == SND_FORMAT_LINEAR_16 ? 2
             : fmt == SND_FORMAT_FLOAT ? 4
             : fmt == SND_FORMAT_DOUBLE ? 8 : 1);
    long off = (long)firstEff * ch * bps;
    long rangeBytes = (long)lenEff * ch * bps;

    unsigned char *expected = malloc ((size_t)size);
    memcpy (expected, before, (size_t)size);
    gateExpected (expected, firstEff, lenEff, ch, threshold, swait, scut, fmt);

    check (memcmp ([snd bytes] + off, expected + off, (size_t)rangeBytes) == 0,
            "gated range matches the 1998 gate arithmetic");
    check (memcmp ([snd bytes], expected, (size_t)size) == 0,
            "the rest of the sound is untouched");

    /* And the gate must actually gate: the samples must sit in
       the zones the state machine implies (loud at or above the
       threshold, quiet below it, closed-gate samples zero).  The
       byte-for-byte equality above matches the module against
       its mirror; these pin the behaviour itself. */
    unsigned char sample[8];
    double hi = gateHiClip (fmt) * (double)threshold;

    int region = (long)firstEff < 100 ? 0 : (firstEff < 600 ? 1 : 2);
    gateReadSample ((const unsigned char *)[snd bytes], (long)firstEff, 0, ch, bps, sample);
    if (region == 1)
        check (gateAbsValue (gateSampleValue (fmt, sample, bps)) >= hi,
               "the selection's first sample is still loud (the released state never scales)");
    else
        check (gateSampleValue (fmt, sample, bps) == 0,
               "the selection's first sample is still silent (the released state never scales)");

    gateReadSample ((const unsigned char *)[snd bytes], 500, 0, ch, bps, sample);
    check (gateAbsValue (gateSampleValue (fmt, sample, bps)) >= hi,
            "the loud run passes the gate untouched");

    long lastFrame = (long)firstEff + (long)lenEff - 1;
    gateReadSample ((const unsigned char *)[snd bytes], lastFrame, 0, ch, bps, sample);
    /* The quiet region starts at frame 600 with the gate released
       and the count at zero: it flips to applied after swait+1
       below-threshold samples and closes scut samples later. */
    if (lastFrame >= 600 + (long)swait + 1 + (long)scut)
        check (gateSampleValue (fmt, sample, bps) == 0,
               "the long quiet tail is gated to silence");
    else
        check (gateSampleValue (fmt, sample, bps) != 0,
               "the short quiet tail ramps but stays open");

    free (before);
    free (expected);
}

/*
The Apply:sender (comb filter) DSP on a conforming sound (mono,
16-bit linear, 44.1k - the only shape the 1998 method accepts
without its modal NSRunAlertPanel conversion prompt, which the
headless gate does not exercise), mirrored operation for
operation: the 65 tap amplitudes read from the slider matrix, the
minval/maxval zero scans (an all-zero curve would walk off the
65-element stack array - the module's fingerprint, the contract's
curves keep the zeros as edge taps only), the signed-short
accumulator that wraps, each tapped sample scaled by its tap's
amplitude over the sum before the short cast, and the range tests
whose <= 0 counts index 0 out of range.

  recursive : the 1998 feedback branch - the source is first
              copied into the new sound (the same frame count), and
              the comb then reads and writes the new sound's buffer
              (the center tap taps the current sample, offset -32).
  otherwise : the new sound carries 64 extra frames, the comb
              reads the source buffer (offset -64), and the extra
              frames come out as the range tests' zeros.
*/
static void combExpected (const signed short *src, signed short *dst,
                          int len, const float *amp, int recursive)
{
    int minval = 0;
    int maxval = 64;
    int x, a, b;
    float sum;

    for (x = 0; amp[x] == 0; x++)
        minval = x;
    for (x = 64; amp[x] == 0; x--)
        maxval = x;

    sum = 0;
    for (x = 0; x <= 64; x++)
        sum += amp[x];

    if (recursive)
        for (x = 0; x < len; x++)
            dst[x] = src[x];

    const signed short *live = recursive ? dst : (const signed short *)src;
    int off = recursive ? 32 : 64;
    int len2 = recursive ? len : len + 64;
    for (b = 0; b < len2; b++)
    {
        signed short accumulator = 0;
        for (a = minval; a <= maxval; a++)
            accumulator += (signed short)(
                b - off + a <= 0 || b - off + a >= len ?
                0 : amp[a] / sum * (float)live[b - off + a]);
        dst[b] = accumulator;
    }
}

/*
The ApplyEcho: (echo filter) DSP on a conforming sound, mirrored
operation for operation: the eight position cells read and
negated (the 1998 theposition), the eight amplitude cells read,
the new sound sized from -Min+Max of the 1998 strict-inequality
Max/Min accumulators (the clamp: Min can never come out positive,
Max can never come out negative), and the eight-tap mix into the
resized buffer, the range tests skipping the samples past either
end.
*/
static void echoExp (const signed short *src, signed short *dst, int len,
                     const int *pos, const float *amp)
{
    int x, a;
    int minval = 0;
    int maxval = 0;

    for (x = 0; x < 8; x++)
    {
        if (pos[x] > maxval)
            maxval = pos[x];
        if (pos[x] < minval)
            minval = pos[x];
    }

    int extraarea = (-minval + maxval);
    int min = (-maxval);
    int theposition[8];
    for (x = 0; x <= 7; x++)
        theposition[x] = -pos[x];

    for (x = 0; x < len + 2 * extraarea; x++)
    {
        int accumulator = 0;
        for (a = 0; a <= 7; a++)
        {
            int idx = x + min + theposition[a];
            if ((idx <= len) && (idx >= 0))
                accumulator += (int)((float)(src[idx]) * amp[a]);
        }
        dst[x] = (signed short)accumulator;
    }
}

/*
The Apply:sender (comb) contract on one 65-tap curve and one
recursive setting, over a conforming sound: the buffer must come
out byte-identical to the 1998 comb arithmetic, the new sound must
be the correctly sized one, and the hand-off must reach the view
and the controller with it.

  which : 0 = the uniform 1/65 curve, 1 = the edge-zero 1/54
          curve (zeros as leading and trailing taps only),
          2 = the single center tap - whose expected shape is
          pinned explicitly below, the 1998 <= 0 range quirk
          being the interesting part.
*/
static void testFilterApply (id module, Ivar ivar, const float *curve,
                             int recursive, unsigned long frames, int which)
{
    printf ("== Apply:sender %s on a %lu-frame sound (curve %d)\n",
            recursive ? "recursive" : "non-recursive", frames, which);

    Snd *snd = [[[Snd alloc] initWithFormat: SND_FORMAT_LINEAR_16
                                channelCount: 1
                                    frames: frames
                              samplingRate: 44100.0] autorelease];
    if (snd == nil || [snd lengthInSampleFrames] != frames
       || [snd channelCount] != 1 || [snd dataFormat] != SND_FORMAT_LINEAR_16)
    {
        check (NO, "Snd construction");
        return;
    }
    fillPattern (snd, 0);

    FakeFilterMatrix *sliders = [[[FakeFilterMatrix alloc] init] autorelease];
    int x;
    for (x = 0; x <= 64; x++)
        [ [sliders cellAtRow: 0 column: x] setFloatValue: curve[x] ];
    FakeFilterValue *rec = [[[FakeFilterValue alloc] init] autorelease];
    [rec setIntValue: recursive];
    FakeFilterValue *pct = [[[FakeFilterValue alloc] init] autorelease];
    FakeFilterValue *epct = [[[FakeFilterValue alloc] init] autorelease];

    FakeFilterView *view =
        [[[FakeFilterView alloc] initWithSound: snd] autorelease];
    FakeFilterController *controller =
        [[[FakeFilterController alloc] initWithSound: snd soundView: view] autorelease];

    object_setIvar (module, ivar, controller);
    object_setIvar (module, class_getInstanceVariable ([module class], "Sliders"), sliders);
    object_setIvar (module, class_getInstanceVariable ([module class], "recursive"), rec);
    object_setIvar (module, class_getInstanceVariable ([module class], "PercentDone"), pct);
    object_setIvar (module, class_getInstanceVariable ([module class], "EchoPercentDone"), epct);

    id ret = [(FilterModule *)module Apply: nil];

    check (ret == module, "Apply:sender returns self");
    check ([view pasteboardCheckCount] == 1, "the pasteboard check ran on the view");
    check ([view soundSetCount] == 1, "the view got setSound:");
    check ([controller newSoundCount] == 1, "the controller got newSound:for:");
    check ([controller ownerQueryCount] == 0, "the PASTE_BUG workaround never fired");
    Snd *out = [view sound];
    check (out != nil && [controller newSound] == out,
            "view and controller got the same sound");
    int expectFrames = recursive ? (int)frames : (int)frames + 64;
    check (out != nil && [out lengthInSampleFrames] == expectFrames
             && [out channelCount] == 1 && [out dataFormat] == SND_FORMAT_LINEAR_16,
            "the new sound keeps the shape, recursive keeps the length, the rest grows by 64");
    check ([pct intValue] == 100, "the percent field ends at 100");

    if (out == nil || [out lengthInSampleFrames] != expectFrames)
        return;

    signed short *expected = malloc ((size_t)expectFrames * sizeof (signed short));
    combExpected ((const signed short *)[snd bytes], expected,
                  (int)frames, curve, recursive);
    check (memcmp ([out bytes], expected,
                   (size_t)expectFrames * sizeof (signed short)) == 0,
            "comb buffer matches the 1998 arithmetic");
    free (expected);

    /* Beyond the byte-for-byte match against the mirror, pin the
       behaviour the shape implies.  With all non-negative
       amplitudes the weights sum to 1, so no sample can grow. */
    {
        const signed short *in = (const signed short *)[snd bytes];
        const signed short *o = (const signed short *)[out bytes];
        int maxIn = 0, maxOut = 0;
        for (x = 0; x < (int)frames; x++)
        {
            int v = abs ((int)in[x]);
            if (v > maxIn)
                maxIn = v;
        }
        for (x = 0; x < expectFrames; x++)
        {
            int v = abs ((int)o[x]);
            if (v > maxOut)
                maxOut = v;
        }
        check (maxOut <= maxIn, "the comb never amplifies (the weights sum to 1)");

        /* The single center tap is the identity, the 1998 <= 0
           range quirk zeroing frame 0 of the recursive copy
           (index 0 counts out of range) and shifting the
           non-recursive one 33 frames early (the 32-frame delay
           plus the quirk's one). */
        if (which == 2)
            {
            int ok = 1;
            if (recursive)
                {
                check (o[0] == 0, "center tap recursive: frame 0 is zero (the <= 0 quirk)");
                for (x = 1; x < (int)frames; x++)
                    if (o[x] != in[x])
                        ok = 0;
                check (ok, "center tap recursive: every other frame is the untouched source");
                }
            else
                {
                ok = 1;
                for (x = 33; x <= (int)frames + 31; x++)
                    if (o[x] != in[x - 32])
                        ok = 0;
                check (ok, "center tap non-recursive: the 32-frame delay");
                ok = 1;
                for (x = 0; x <= 32; x++)
                    if (o[x] != 0)
                        ok = 0;
                check (ok, "center tap non-recursive: the 33 leading zeros (the quirk's one included)");
                ok = 1;
                for (x = (int)frames + 32; x < (int)frames + 64; x++)
                    if (o[x] != 0)
                        ok = 0;
                check (ok, "center tap non-recursive: the 32 trailing zeros");
                }
            }
    }
}

/*
The ApplyEcho: (echo) contract on one position shape (eight
cells) and one amplitude shape, over a conforming sound: the
buffer must come out byte-identical to the 1998 echo arithmetic,
the new sound must be sized from the 1998 Max/Min clamp, and the
hand-off must reach the view and the controller with it.
*/
static void testFilterApplyEcho (id module, Ivar ivar, const int *pos,
                                 const float *amp, unsigned long frames)
{
    printf ("== ApplyEcho: positions %d..%d on a %lu-frame sound\n",
            pos[0], pos[7], frames);

    Snd *snd = [[[Snd alloc] initWithFormat: SND_FORMAT_LINEAR_16
                                channelCount: 1
                                    frames: frames
                              samplingRate: 44100.0] autorelease];
    if (snd == nil || [snd lengthInSampleFrames] != frames
       || [snd channelCount] != 1 || [snd dataFormat] != SND_FORMAT_LINEAR_16)
    {
        check (NO, "Snd construction");
        return;
    }
    fillPattern (snd, 1);

    FakeFilterMatrix *position = [[[FakeFilterMatrix alloc] init] autorelease];
    FakeFilterMatrix *amplitude = [[[FakeFilterMatrix alloc] init] autorelease];
    int x;
    for (x = 0; x < 8; x++)
    {
        [ [position cellAtRow: x column: 0] setIntValue: pos[x] ];
        [ [amplitude cellAtRow: x column: 0] setFloatValue: amp[x] ];
    }
    FakeFilterValue *epct = [[[FakeFilterValue alloc] init] autorelease];

    FakeFilterView *view =
        [[[FakeFilterView alloc] initWithSound: snd] autorelease];
    FakeFilterController *controller =
        [[[FakeFilterController alloc] initWithSound: snd soundView: view] autorelease];

    object_setIvar (module, ivar, controller);
    object_setIvar (module, class_getInstanceVariable ([module class], "Position"), position);
    object_setIvar (module, class_getInstanceVariable ([module class], "Amplitude"), amplitude);
    object_setIvar (module, class_getInstanceVariable ([module class], "EchoPercentDone"), epct);

    /* The 1998 Max/Min clamp, driven by the same cells the method
       reads: an all-positive matrix leaves Min at 0 (it
       accumulates from 0 with a strict <), an all-negative one
       leaves Max at 0 - the buffer sizing follows the clamp. */
    int minv = 0, maxv = 0;
    for (x = 0; x < 8; x++)
    {
        if (pos[x] < minv)
            minv = pos[x];
        if (pos[x] > maxv)
            maxv = pos[x];
    }
    check ([ (FilterModule *)module Max ] == maxv
             && [ (FilterModule *)module Min ] == minv,
            "Max/Min clamp as in the 1998 strict-inequality accumulators");

    id ret = [(FilterModule *)module ApplyEcho: nil];

    check (ret == module, "ApplyEcho: returns self");
    check ([view pasteboardCheckCount] == 1, "the pasteboard check ran on the view");
    check ([view soundSetCount] == 1, "the view got setSound:");
    check ([controller newSoundCount] == 1, "the controller got newSound:for:");
    Snd *out = [view sound];
    check (out != nil && [controller newSound] == out,
            "view and controller got the same sound");
    int expectFrames = (int)frames + 2 * ((-minv) + maxv);
    check (out != nil && [out lengthInSampleFrames] == expectFrames
             && [out channelCount] == 1 && [out dataFormat] == SND_FORMAT_LINEAR_16,
            "the new sound is sized from the clamped -Min+Max, shape kept");
    check ([epct intValue] == 100, "the echo percent field ends at 100");

    if (out == nil || [out lengthInSampleFrames] != expectFrames)
        return;

    signed short *expected = malloc ((size_t)expectFrames * sizeof (signed short));
    echoExp ((const signed short *)[snd bytes], expected,
             (int)frames, pos, amp);
    check (memcmp ([out bytes], expected,
                   (size_t)expectFrames * sizeof (signed short)) == 0,
            "echo buffer matches the 1998 arithmetic");
    free (expected);

    /* Beyond the byte-for-byte match: the all-positive positions
       leave Min clamped at 0 and Max at the largest, so the
       biggest index the range tests compute sits 27 frames before
       the source start - 27 leading zero frames. */
    if (minv == 0)
        {
        const signed short *o = (const signed short *)[out bytes];
        int ok = 1;
        for (x = 0; x < 27; x++)
            if (o[x] != 0)
                ok = 0;
        check (ok, "all-positive positions: 27 leading zero frames (the clamped Min)");
        }
}

static void runEcho (Class principal)
{
    /* The menu tree the app's Modules menu is built from: one leaf,
       named with the 1998 three dots, targeting begin:. */
    id module = [[principal alloc] init];
    check (module != nil, "module instantiation");
    id root = [module getModuleMenuNode];
    check (root != nil, "root menu node");
    check (root != nil && [root numSubmenus] == 1, "root has exactly one submenu");
    id leaf = root != nil ? [root getSubmenu: 0] : nil;
    check (leaf != nil && [leaf isLeafNode], "leaf node");
    check (leaf != nil && [[leaf getNameAsString] isEqualToString: @"Echo Chamber..."],
            "leaf is named Echo Chamber...");
    check (leaf != nil && [NSStringFromSelector ([leaf getMessage]) isEqualToString: @"begin:"],
            "leaf targets begin:");
    check (leaf != nil && [leaf getReceiver] == module, "leaf targets the module");

    /* The controller ivar (inherited from Module) and the six outlet
       ivars the 1998 header declares; the gorm connects all six (the
       probe of the real wiring: three text field cells, two slider
       cells, the panel window), so all must exist and start nil, and
       the windowLoaded flag must start unset. */
    Ivar ivar = class_getInstanceVariable ([module class], "moduleController");
    check (ivar != NULL, "moduleController ivar (for the DSP cases)");
    static const char *outletNames[] = {
        "delay", "dropoff", "initial", "firstDelay", "ratio", "EchoChamberPanel"
    };
    int o;
    for (o = 0; o < 6; o++)
    {
        char what[80];
        snprintf (what, sizeof what, "%s ivar exists", outletNames[o]);
        check (class_getInstanceVariable ([module class], outletNames[o]) != NULL, what);
        snprintf (what, sizeof what, "%s ivar starts nil", outletNames[o]);
        check (readObjIvar (module, outletNames[o]) == nil, what);
    }
    check (readIntIvar (module, "windowLoaded") == 0, "windowLoaded starts unset");

    /* begin: with the panel outlet pre-set to a fake and
       windowLoaded pre-set (a real panel load needs a display - the
       app-side half is the resoundmenu --perform probe, where the
       gorm panel comes up for real): the 1998 method then just
       orders the panel key and front, and stays quiet about it. */
    Ivar winIvar = class_getInstanceVariable ([module class], "windowLoaded");
    Ivar panelIvar = class_getInstanceVariable ([module class], "EchoChamberPanel");
    check (winIvar != NULL && panelIvar != NULL, "windowLoaded/panel ivars");
    FakeEchoPanel *panel = [[[FakeEchoPanel alloc] init] autorelease];
    object_setIvar (module, winIvar, (id)(intptr_t)1);
    object_setIvar (module, panelIvar, panel);

    id ret = [(EchoChamber *)module begin: nil];
    check (ret == module, "begin: returns self");
    check ([panel keyFrontCount] == 1, "begin: ordered the panel key and front");
    [(EchoChamber *)module begin: nil];
    check ([panel keyFrontCount] == 2, "begin: is repeatable (the loaded flag stays set)");

    /* The echo DSP, three shapes of the constants:
       - the gorm's defaults in range (both echo branches engage);
       - zero first delay (the addvalue branch engages from sample 1);
       - a sound shorter than both delays (pure copy, sample 0 zero). */
    testEcho (module, ivar, 0.02f, 0.9f, 0.5f, 0.005f, 0.3f, 1000);
    testEcho (module, ivar, 0.0f, 0.9f, 0.5f, 0.005f, 0.3f, 1000);
    testEcho (module, ivar, 0.02f, 0.9f, 0.5f, 0.005f, 0.3f, 100);
}

static void runGate (Class principal)
{
    /* The menu tree the app's Modules menu is built from: one
       leaf, named with the 1998 three dots, targeting
       showNoiseGatePanel:. */
    id module = [[principal alloc] init];
    check (module != nil, "module instantiation");
    id root = [module getModuleMenuNode];
    check (root != nil, "root menu node");
    check (root != nil && [root numSubmenus] == 1, "root has exactly one submenu");
    id leaf = root != nil ? [root getSubmenu: 0] : nil;
    check (leaf != nil && [leaf isLeafNode], "leaf node");
    check (leaf != nil && [[leaf getNameAsString] isEqualToString: @"Noise Gate..."],
            "leaf is named Noise Gate...");
    check (leaf != nil && [NSStringFromSelector ([leaf getMessage]) isEqualToString: @"showNoiseGatePanel:"],
            "leaf targets showNoiseGatePanel:");
    check (leaf != nil && [leaf getReceiver] == module, "leaf targets the module");

    /* The controller ivar (inherited from Module) and the four
       outlet ivars the 1998 header declares; the gorm connects
       all four (the probe of the real wiring: the panel
       window, three text field views), so all must exist and
       start in the un-wired state, and the nib_loaded flag
       must start unset. */
    Ivar ivar = class_getInstanceVariable ([module class], "moduleController");
    check (ivar != NULL, "moduleController ivar (for the DSP cases)");
    static const char *outletNames[] = {
        "gatePanel", "thresholdField", "secondsWaitField", "secondsCutField"
    };
    int o;
    for (o = 0; o < 4; o++)
    {
        char what[80];
        snprintf (what, sizeof what, "%s ivar exists", outletNames[o]);
        check (class_getInstanceVariable ([module class], outletNames[o]) != NULL, what);
        snprintf (what, sizeof what, "%s ivar starts nil", outletNames[o]);
        check (readObjIvar (module, outletNames[o]) == nil, what);
    }
    check (readSizedIvar (module, "nib_loaded") == 0, "nib_loaded starts unset");

    /* showNoiseGatePanel: with the panel pre-set to a fake and
       the nib_loaded flag pre-set through the sized ivar
       helpers (a real panel load needs a display - the
       app-side half is the resoundmenu --perform probe, where
       the gorm panel comes up for real): the 1998 method then
       just orders the panel key and front, and stays quiet
       about it. */
    Ivar flagIvar = class_getInstanceVariable ([module class], "nib_loaded");
    Ivar panelIvar = class_getInstanceVariable ([module class], "gatePanel");
    check (flagIvar != NULL && panelIvar != NULL, "nib_loaded/panel ivars");
    FakeGatePanel *panel = [[[FakeGatePanel alloc] init] autorelease];
    writeSizedIvar (module, "nib_loaded", 1);
    check (readSizedIvar (module, "nib_loaded") == 1, "the sized flag write round-trips");
    object_setIvar (module, panelIvar, panel);

    id ret = [(GateModule *)module showNoiseGatePanel: nil];
    check (ret == module, "showNoiseGatePanel: returns self");
    check ([panel keyFrontCount] == 1, "showNoiseGatePanel: ordered the panel key and front");
    [(GateModule *)module showNoiseGatePanel: nil];
    check ([panel keyFrontCount] == 2, "showNoiseGatePanel: is repeatable (the loaded flag stays set)");

    /* The gate DSP: the five 1998 formats, mono and stereo, a
       whole-sound selection, then a partial one. */
    int c;
    int ch;
    for (c = 0; c < 5; c++)
        for (ch = 1; ch <= 2; ch++)
            testGate (module, ivar, (SndSampleFormat)dspFormats[c], ch, 0, 0, 1200);
    for (c = 0; c < 5; c++)
        for (ch = 1; ch <= 2; ch++)
            testGate (module, ivar, (SndSampleFormat)dspFormats[c], ch, 400, 500, 1200);
}

static void runFilter (Class principal)
{
    /* The menu tree the app's Modules menu is built from: one
       submenu, "Filter", with exactly two leaves - the 1998
       three-dot names, each targeting the module itself.  (The
       first of the ported modules with a submenu - and with two
       panels.) */
    id module = [[principal alloc] init];
    check (module != nil, "module instantiation");
    id root = [module getModuleMenuNode];
    check (root != nil, "root menu node");
    check (root != nil && [root numSubmenus] == 1, "root has exactly one submenu");
    id sub = root != nil ? [root getSubmenu: 0] : nil;
    check (sub != nil && ![sub isLeafNode], "the submenu is not a leaf");
    check (sub != nil && [[sub getNameAsString] isEqualToString: @"Filter"],
            "the submenu is named Filter");
    check (sub != nil && [sub numSubmenus] == 2, "the submenu holds exactly two leaves");
    static const char *leafNames[] = { "Comb Filter...", "Echo Filter..." };
    static const char *leafTargets[] = { "LoadFilterPanel:", "LoadEchoFilterPanel:" };
    int i;
    for (i = 0; i < 2; i++)
        {
        char what[80];
        id leaf = sub != nil ? [sub getSubmenu: i] : nil;
        check (leaf != nil && [leaf isLeafNode], "leaf node");
        snprintf (what, sizeof what, "leaf %d is named %s", i, leafNames[i]);
        check (leaf != nil && [[leaf getNameAsString] isEqualToString: [NSString stringWithUTF8String: leafNames[i]]],
                what);
        snprintf (what, sizeof what, "leaf %d targets %s", i, leafTargets[i]);
        check (leaf != nil && [NSStringFromSelector ([leaf getMessage]) isEqualToString: [NSString stringWithUTF8String: leafTargets[i]]],
                what);
        check (leaf != nil && [leaf getReceiver] == module, "leaf targets the module");
        }

    /* The controller ivar (inherited from Module) and the eight
       outlet ivars the 1998 header declares - all eight wired by
       the gorm (the probe of the real wiring: the slider matrix,
       the percent field, the position matrix, the amplitude
       matrix, the echo percent field, the two panel windows, the
       recursive button) - so all must exist and start nil, and
       the WindowLoaded flag must start unset. */
    Ivar ivar = class_getInstanceVariable ([module class], "moduleController");
    check (ivar != NULL, "moduleController ivar (for the DSP cases)");
    static const char *outletNames[] = {
        "Sliders", "PercentDone", "Position", "Amplitude",
        "EchoPercentDone", "FilterPanel", "EchoFilterPanel", "recursive"
    };
    int o;
    for (o = 0; o < 8; o++)
        {
        char what[80];
        snprintf (what, sizeof what, "%s ivar exists", outletNames[o]);
        check (class_getInstanceVariable ([module class], outletNames[o]) != NULL, what);
        snprintf (what, sizeof what, "%s ivar starts nil", outletNames[o]);
        check (readObjIvar (module, outletNames[o]) == nil, what);
        }
    check (readIntIvar (module, "WindowLoaded") == 0, "WindowLoaded starts unset");

    /* The two panel methods with the flag pre-set (a real panel
       load needs a display - the app-side half is the resoundmenu
       --perform probe, where the gorm panel comes up for real):
       each then just orders its panel key and front.  The 1998
       WindowLoaded is a full int (not the Gate's one-byte flag),
       so a pointer-sized object_setIvar is exact on it. */
    Ivar winIvar = class_getInstanceVariable ([module class], "WindowLoaded");
    Ivar combPanelIvar = class_getInstanceVariable ([module class], "FilterPanel");
    Ivar echoPanelIvar = class_getInstanceVariable ([module class], "EchoFilterPanel");
    check (winIvar != NULL && combPanelIvar != NULL && echoPanelIvar != NULL,
            "WindowLoaded/panel ivars");
    FakeFilterPanel *combPanel = [[[FakeFilterPanel alloc] init] autorelease];
    FakeFilterPanel *echoPanel = [[[FakeFilterPanel alloc] init] autorelease];
    object_setIvar (module, winIvar, (id)(intptr_t)1);
    object_setIvar (module, combPanelIvar, combPanel);
    object_setIvar (module, echoPanelIvar, echoPanel);

    id ret = [(FilterModule *)module LoadFilterPanel: nil];
    check (ret == module, "LoadFilterPanel: returns self");
    check ([combPanel keyFrontCount] == 1, "LoadFilterPanel: ordered the comb panel key and front");
    check ([echoPanel keyFrontCount] == 0, "LoadFilterPanel: left the echo panel alone");
    [(FilterModule *)module LoadFilterPanel: nil];
    check ([combPanel keyFrontCount] == 2, "LoadFilterPanel: is repeatable (the loaded flag stays set)");

    ret = [(FilterModule *)module LoadEchoFilterPanel: nil];
    check (ret == module, "LoadEchoFilterPanel: returns self");
    check ([echoPanel keyFrontCount] == 1, "LoadEchoFilterPanel: ordered the echo panel key and front");
    check ([combPanel keyFrontCount] == 2, "LoadEchoFilterPanel: left the comb panel alone");
    check (readIntIvar (module, "WindowLoaded") == 1, "the flag reads back as set");

    /* The comb DSP: three shapes of the 65-tap curve (the uniform
       1/65, the edge-zero 1/54, the single center tap) x the
       recursive setting.  2000 frames for the wide curves, 1500
       for the center tap (both keep datalength/1000 off zero for
       the 1998 percent modulo). */
    float uniform[65];
    float edged[65];
    float center[65];
    int x;
    for (x = 0; x <= 64; x++)
        {
        uniform[x] = 1.0f / 65.0f;
        edged[x] = (x >= 5 && x <= 58) ? 1.0f / 54.0f : 0.0f;
        center[x] = (x == 32) ? 1.0f : 0.0f;
        }
    testFilterApply (module, ivar, uniform, 1, 2000, 0);
    testFilterApply (module, ivar, uniform, 0, 2000, 0);
    testFilterApply (module, ivar, edged, 1, 2000, 1);
    testFilterApply (module, ivar, edged, 0, 2000, 1);
    testFilterApply (module, ivar, center, 1, 1500, 2);
    testFilterApply (module, ivar, center, 0, 1500, 2);

    /* The echo DSP: the two position shapes that pin the 1998
       Max/Min clamp from opposite sides (all-positive leaves Min
       at 0, all-negative leaves Max at 0), same amplitudes. */
    static const int posPos[8] = { 10, 11, 12, 13, 14, 15, 16, 17 };
    static const int posNeg[8] = { -17, -16, -15, -14, -13, -12, -11, -10 };
    static const float amps[8] = { 0.8f, 0.6f, 0.4f, 0.2f, 0.1f, 0.05f, 0.02f, 0.01f };
    testFilterApplyEcho (module, ivar, posPos, amps, 2000);
    testFilterApplyEcho (module, ivar, posNeg, amps, 2000);
}

/*
The 1998 sine arithmetic, mirrored exactly as the module runs
it: zero the whole buffer, then for each active harmonic (the
1998 frequency && amplitude if) add the 32767-scaled sine of
the harmonic - the int accumulator over the double product (the
1998 2*3.1415 is a double), the SHRT_MAX / SHRT_MIN clamps, the
signed-short store, so the expectation is bit-exact against the
module's buffer.
*/
static void sinExpected (const float *freq, const float *amp,
                         const float *ph, int length,
                         signed short *expected)
{
    int x;
    int y;
    for (y = 0; y < length; y++)
        expected[y] = 0;
    for (x = 0; x < 16; x++)
        if (freq[x] && amp[x])
            for (y = 0; y < length; y++)
            {
            int tempvalue = expected[y] +
                (32767*amp[x]*sin((y*freq[x]*2*3.1415)/44100+ph[x]));
            if (tempvalue > SHRT_MAX)
                tempvalue = SHRT_MAX;
            if (tempvalue < SHRT_MIN)
                tempvalue = SHRT_MIN;
            expected[y] = (signed short)tempvalue;
            }
}

/*
The 1998 "other waves" arithmetic, mirrored through the
byte-identical waveform function above: the 1998 wavelength
(1/frequency*44100 truncated to int), the 32767-scaled
amplitude, the per-frame waveform value cast to signed short -
the same truncations, the same order.
*/
static void othersExpected (float (*wave) (int, int), int length,
                            float frequency, float ampField,
                            signed short *expected)
{
    int wavelength = (int)(1/frequency*44100);
    float amplitude = 32767*ampField;
    int y;
    for (y = 0; y < length; y++)
        expected[y] = (signed short)(amplitude*wave(y, wavelength));
}

/*
The generateSin: contract on one harmonic shape: set the length
field and the three 16-row matrices through the same string
writes the real controls carry, run the method, and check the
brandNewSound: hand-off, the shape of the fresh sound, the
percent counter, and the buffer against the mirrored 1998
arithmetic.  A zero length is the 1998 guard - no sound at all,
the percent sentinel untouched.
*/
static void testWaveGenerateSin (id module, int frames, const float *freq,
                                 const float *amp, const float *ph)
{
    /* The injected outlets as their concrete fake types (the id
       form would trip -Wobjc-multiple-method-names where a
       control of AppKit's declares the same selector - the Filter
       contract's concrete fakes keep the dispatch unambiguous). */
    FakeWaveField *length = readObjIvar (module, "sinLength");
    FakeWaveField *percent = readObjIvar (module, "percentDoneSin");
    FakeSinMatrix *harmonics = readObjIvar (module, "sinHarmonics");
    FakeSinMatrix *amplitudes = readObjIvar (module, "sinAmplitudes");
    FakeSinMatrix *phases = readObjIvar (module, "sinPhases");
    FakeWaveController *controller = readObjIvar (module, "moduleController");
    int before = [controller newSoundCount];
    int active = 0;
    int x;
    for (x = 0; x < 16; x++)
        if (freq[x] && amp[x])
            active++;

    [length setStringValue: [NSString stringWithFormat: @"%d", frames]];
    for (x = 0; x < 16; x++)
        {
        [ [harmonics cellAtRow: x column: 0]
          setStringValue: [NSString stringWithFormat: @"%g", freq[x]] ];
        [ [amplitudes cellAtRow: x column: 0]
          setStringValue: [NSString stringWithFormat: @"%g", amp[x]] ];
        [ [phases cellAtRow: x column: 0]
          setStringValue: [NSString stringWithFormat: @"%g", ph[x]] ];
        }
    [percent setStringValue: @"55"];

    id ret = [(WaveBuilderModule *)module generateSin: nil];

    check (ret == module, "generateSin: returns self");
    check ([controller newSoundCount] == before + (frames ? 1 : 0),
           "the controller got the fresh sound (the length-0 guard builds none)");
    check ([percent intValue] == (frames ? active : 55),
           "the percent counter counts the active harmonics (the guard leaves it alone)");
    if (!frames)
        return;
    Snd *out = [controller newSound];
    check (out != nil && [out lengthInSampleFrames] == (unsigned long)frames
             && [out channelCount] == 1
             && [out dataFormat] == SND_FORMAT_LINEAR_16
             && [out samplingRate] == SND_RATE_HIGH,
            "the fresh sound is 16-bit mono 44.1k, sized from the length field");
    if (out == nil)
        return;
    signed short *expected = malloc ((size_t)frames * sizeof (signed short));
    sinExpected (freq, amp, ph, frames, expected);
    check (memcmp ([out bytes], expected,
                   (size_t)frames * sizeof (signed short)) == 0,
            "sine buffer matches the 1998 arithmetic");
    free (expected);
}

/*
The generateOthers: contract on one waveform: the doX: setter
that picks it (the 1998 "Type" pull-down drives the same five),
the length / size / amplitude fields, and the run - the 1998
guard is length && frequency && amplitude, so any zero field
skips the whole generation.  The percent counter and the
buffer are checked against the mirrored 1998 arithmetic; the
noise case through the re-seeded rand sequence, the module
consuming one rand() per frame.
*/
static void testWaveGenerateOthers (id module, const char *wave,
                                    int expectedWhich, SEL doX,
                                    int frames, const char *sizeStr,
                                    const char *ampStr,
                                    float (*waveFn) (int, int))
{
    FakeWaveField *length = readObjIvar (module, "othersLength");
    FakeWaveField *size = readObjIvar (module, "othersSize");
    FakeWaveField *amp = readObjIvar (module, "othersAmplitude");
    FakeWaveField *percent = readObjIvar (module, "percentDoneOthers");
    FakeWaveController *controller = readObjIvar (module, "moduleController");
    int before = [controller newSoundCount];
    char what[80];

    [(WaveBuilderModule *)module performSelector: doX withObject: nil];
    snprintf (what, sizeof what, "%s: doX: sets whichToDo", wave);
    /* whichToDo sits ahead of the windowLoaded int, which the
       panel cases above set: the type-encoding-aware sized read
       takes exactly the 4 bytes, where the pointer-sized
       readIntIvar would sweep in the neighbor's bit. */
    check (readSizedIvar (module, "whichToDo") == expectedWhich, what);

    [length setStringValue: [NSString stringWithFormat: @"%d", frames]];
    [size setStringValue: [NSString stringWithUTF8String: sizeStr]];
    [amp setStringValue: [NSString stringWithUTF8String: ampStr]];
    [percent setStringValue: @"55"];

    /* The module and the expectation run in this one process, so
       a re-seeded rand() regenerates exactly the sequence the
       module consumed. */
    srand (1998);
    id ret = [(WaveBuilderModule *)module generateOthers: nil];
    srand (1998);

    int expect = ([length intValue] && [size floatValue] && [amp floatValue])
        ? 1 : 0;
    snprintf (what, sizeof what, "%s: returns self", wave);
    check (ret == module, what);
    snprintf (what, sizeof what, "%s: the controller got the fresh sound", wave);
    check ([controller newSoundCount] == before + expect, what);
    snprintf (what, sizeof what, "%s: the percent counter ends right", wave);
    check ([percent intValue] == (expect ? 100 : 55), what);
    if (!expect)
        return;
    Snd *out = [controller newSound];
    check (out != nil && [out lengthInSampleFrames] == (unsigned long)frames
             && [out channelCount] == 1
             && [out dataFormat] == SND_FORMAT_LINEAR_16
             && [out samplingRate] == SND_RATE_HIGH,
            "the fresh sound is 16-bit mono 44.1k, sized from the length field");
    if (out == nil)
        return;
    signed short *expected = malloc ((size_t)frames * sizeof (signed short));
    othersExpected (waveFn, frames, [size floatValue], [amp floatValue], expected);
    snprintf (what, sizeof what, "%s: buffer matches the 1998 arithmetic", wave);
    check (memcmp ([out bytes], expected,
                   (size_t)frames * sizeof (signed short)) == 0, what);
    free (expected);
}

static void runWaveBuilder (Class principal)
{
    /* The menu tree the app's Modules menu is built from: one
       submenu, "Generate Sounds", with exactly two leaves - the
       1998 three-dot names, each targeting the module itself.
       (The first of the ported modules that generates: the two
       panel methods only bring the panels up, and the generate
       methods build a fresh sound - no current sound anywhere.) */
    id module = [[principal alloc] init];
    check (module != nil, "module instantiation");
    id root = [module getModuleMenuNode];
    check (root != nil, "root menu node");
    check (root != nil && [root numSubmenus] == 1, "root has exactly one submenu");
    id sub = root != nil ? [root getSubmenu: 0] : nil;
    check (sub != nil && ![sub isLeafNode], "the submenu is not a leaf");
    check (sub != nil && [[sub getNameAsString] isEqualToString: @"Generate Sounds"],
            "the submenu is named Generate Sounds");
    check (sub != nil && [sub numSubmenus] == 2, "the submenu holds exactly two leaves");
    static const char *leafNames[] = { "Sine Harmonics...", "Other Waves..." };
    static const char *leafTargets[] = { "loadSinPanel:", "loadOthersPanel:" };
    int i;
    for (i = 0; i < 2; i++)
        {
        char what[80];
        id leaf = sub != nil ? [sub getSubmenu: i] : nil;
        check (leaf != nil && [leaf isLeafNode], "leaf node");
        snprintf (what, sizeof what, "leaf %d is named %s", i, leafNames[i]);
        check (leaf != nil && [[leaf getNameAsString] isEqualToString: [NSString stringWithUTF8String: leafNames[i]]],
                what);
        snprintf (what, sizeof what, "leaf %d targets %s", i, leafTargets[i]);
        check (leaf != nil && [NSStringFromSelector ([leaf getMessage]) isEqualToString: [NSString stringWithUTF8String: leafTargets[i]]],
                what);
        check (leaf != nil && [leaf getReceiver] == module, "leaf targets the module");
        }

    /* The controller ivar (inherited from Module) and the fifteen
       outlet ivars the 1998 header declares - the three 16x1
       value matrices, their three text twins, the two length
       fields, the size and amplitude fields, the two percent
       counters, the pull-down, the two panel windows - all must
       exist and start nil, and the 1998 whichToDo / windowLoaded
       ints must start at their init values (DOSQUARE, unset). */
    Ivar ivar = class_getInstanceVariable ([module class], "moduleController");
    check (ivar != NULL, "moduleController ivar (for the hand-off cases)");
    static const char *outletNames[] = {
        "sinHarmonics", "sinAmplitudes", "sinPhases",
        "sinTextHarmonics", "sinTextAmplitudes", "sinTextPhases",
        "sinLength", "othersLength", "othersSize", "othersAmplitude",
        "percentDoneSin", "percentDoneOthers",
        "sinPopUpButton", "sinPanel", "othersPanel"
    };
    int o;
    for (o = 0; o < 15; o++)
        {
        char what[80];
        snprintf (what, sizeof what, "%s ivar exists", outletNames[o]);
        check (class_getInstanceVariable ([module class], outletNames[o]) != NULL, what);
        snprintf (what, sizeof what, "%s ivar starts nil", outletNames[o]);
        check (readObjIvar (module, outletNames[o]) == nil, what);
        }
    /* whichToDo reads through the type-encoding-aware sized helper
       (the pointer-sized readIntIvar would sweep in the bytes of
       the windowLoaded int behind it).  windowLoaded is the last
       ivar, so the pointer-sized read is exact on it, the Filter
       way. */
    check (readSizedIvar (module, "whichToDo") == 0, "whichToDo starts at DOSQUARE");
    check (readIntIvar (module, "windowLoaded") == 0, "windowLoaded starts unset");

    /* All fifteen outlets as fakes, plus the generator's one
       hand-off partner: the app's ModuleController - the 1998
       module never reads the document, it only hands the freshly
       built sound off through brandNewSound:.  The six text
       fields start at their gorm values, the matrices at their
       16x1 zeroes, and the 1998 full-int windowLoaded flag is
       pre-set the pointer-sized way (the Filter precedent), so
       the panel methods skip the nib load (a real load needs a
       display - the app-side half is the resoundmenu --perform
       probe, where the gorm panels come up for real). */
    FakeSinMatrix *harmonics = [[[FakeSinMatrix alloc] init] autorelease];
    FakeSinMatrix *amplitudes = [[[FakeSinMatrix alloc] init] autorelease];
    FakeSinMatrix *phases = [[[FakeSinMatrix alloc] init] autorelease];
    FakeSinMatrix *textHarmonics = [[[FakeSinMatrix alloc] init] autorelease];
    FakeSinMatrix *textAmplitudes = [[[FakeSinMatrix alloc] init] autorelease];
    FakeSinMatrix *textPhases = [[[FakeSinMatrix alloc] init] autorelease];
    FakeWaveField *sinLength =
        [[[FakeWaveField alloc] initWithString: @"44100"] autorelease];
    FakeWaveField *othersLength =
        [[[FakeWaveField alloc] initWithString: @"44100"] autorelease];
    FakeWaveField *othersSize =
        [[[FakeWaveField alloc] initWithString: @"0"] autorelease];
    FakeWaveField *othersAmplitude =
        [[[FakeWaveField alloc] initWithString: @"0"] autorelease];
    FakeWaveField *percentDoneSin =
        [[[FakeWaveField alloc] initWithString: @"0"] autorelease];
    FakeWaveField *percentDoneOthers =
        [[[FakeWaveField alloc] initWithString: @"0"] autorelease];
    FakeWavePopUp *popUp = [[[FakeWavePopUp alloc] init] autorelease];
    FakeWavePanel *sinPanel = [[[FakeWavePanel alloc] init] autorelease];
    FakeWavePanel *othersPanel = [[[FakeWavePanel alloc] init] autorelease];
    FakeWaveController *controller = [[[FakeWaveController alloc] init] autorelease];

    object_setIvar (module, ivar, controller);
    object_setIvar (module, class_getInstanceVariable ([module class], "sinHarmonics"), harmonics);
    object_setIvar (module, class_getInstanceVariable ([module class], "sinAmplitudes"), amplitudes);
    object_setIvar (module, class_getInstanceVariable ([module class], "sinPhases"), phases);
    object_setIvar (module, class_getInstanceVariable ([module class], "sinTextHarmonics"), textHarmonics);
    object_setIvar (module, class_getInstanceVariable ([module class], "sinTextAmplitudes"), textAmplitudes);
    object_setIvar (module, class_getInstanceVariable ([module class], "sinTextPhases"), textPhases);
    object_setIvar (module, class_getInstanceVariable ([module class], "sinLength"), sinLength);
    object_setIvar (module, class_getInstanceVariable ([module class], "othersLength"), othersLength);
    object_setIvar (module, class_getInstanceVariable ([module class], "othersSize"), othersSize);
    object_setIvar (module, class_getInstanceVariable ([module class], "othersAmplitude"), othersAmplitude);
    object_setIvar (module, class_getInstanceVariable ([module class], "percentDoneSin"), percentDoneSin);
    object_setIvar (module, class_getInstanceVariable ([module class], "percentDoneOthers"), percentDoneOthers);
    object_setIvar (module, class_getInstanceVariable ([module class], "sinPopUpButton"), popUp);
    object_setIvar (module, class_getInstanceVariable ([module class], "sinPanel"), sinPanel);
    object_setIvar (module, class_getInstanceVariable ([module class], "othersPanel"), othersPanel);
    object_setIvar (module, class_getInstanceVariable ([module class], "windowLoaded"),
                    (id)(intptr_t)1);

    /* The two panel methods with the flag pre-set (a real panel
       load needs a display - the app-side half is the resoundmenu
       --perform probe, where the gorm panels come up for real). */
    id ret = [(WaveBuilderModule *)module loadSinPanel: nil];
    check (ret == module, "loadSinPanel: returns self");
    check ([popUp pullsDown] == YES, "loadSinPanel: flipped the pull-down to pulls-down");
    check ([[popUp title] isEqualToString: @"Actions..."],
           "loadSinPanel: re-set the pull-down title");
    check ([sinPanel keyFrontCount] == 1, "loadSinPanel: ordered the sine panel key and front");
    check ([othersPanel keyFrontCount] == 0, "loadSinPanel: left the others panel alone");
    [(WaveBuilderModule *)module loadSinPanel: nil];
    check ([sinPanel keyFrontCount] == 2, "loadSinPanel: is repeatable (the loaded flag stays set)");
    ret = [(WaveBuilderModule *)module loadOthersPanel: nil];
    check (ret == module, "loadOthersPanel: returns self");
    check ([othersPanel keyFrontCount] == 1, "loadOthersPanel: ordered the others panel key and front");
    check ([sinPanel keyFrontCount] == 2, "loadOthersPanel: left the sine panel alone");
    check (readIntIvar (module, "windowLoaded") == 1, "the flag reads back as set");

    /* The sine generator: the 1998 panel default - one active
       harmonic (440, amplitude 1, phase 0) over the gorm's full
       second - then two active harmonics (the percent counter
       counts both, the second adds into the first's buffer in
       the 1998 order), then a saturating amplitude (the 1998
       SHRT_MAX / SHRT_MIN clamps), then the length-0 guard. */
    static const float freq0[16] = { 440 };
    static const float amp0[16] = { 1 };
    static const float ph0[16] = { 0 };
    testWaveGenerateSin (module, 44100, freq0, amp0, ph0);
    static const float freq1[16] = { 440, 880 };
    static const float amp1[16] = { 1, 0.5 };
    static const float ph1[16] = { 0, 1.0 };
    testWaveGenerateSin (module, 4410, freq1, amp1, ph1);
    static const float amp2[16] = { 2.0 };
    testWaveGenerateSin (module, 2000, freq0, amp2, ph0);
    testWaveGenerateSin (module, 0, freq0, amp0, ph0);

    /* The five "other waves" (the 1998 "Type" pull-down drives
       the doX: setters that pick them): 1000 frames of a 440 Hz
       size, unit amplitude - the 1998 wavelength is 100, and
       each waveform runs through the mirrored arithmetic, the
       noise through the re-seeded rand sequence. */
    testWaveGenerateOthers (module, "square", 0, @selector(doSquare:),
                            1000, "440", "1", wbSquare);
    testWaveGenerateOthers (module, "triangle", 1, @selector(doTriangle:),
                            1000, "440", "1", wbTriangle);
    testWaveGenerateOthers (module, "noise", 2, @selector(doNoise:),
                            1000, "440", "1", wbNoise);
    testWaveGenerateOthers (module, "sawtooth", 3, @selector(doSawtooth:),
                            1000, "440", "1", wbSawtooth);
    testWaveGenerateOthers (module, "pulse", 4, @selector(doPulse:),
                            1000, "440", "1", wbPulse);

    /* The 1998 guard: length && frequency && amplitude - any
       zero field skips the whole generation. */
    testWaveGenerateOthers (module, "square", 0, @selector(doSquare:),
                            0, "440", "1", wbSquare);
    testWaveGenerateOthers (module, "square", 0, @selector(doSquare:),
                            1000, "0", "1", wbSquare);
    testWaveGenerateOthers (module, "square", 0, @selector(doSquare:),
                            1000, "440", "0", wbSquare);

    /* The note actions: each clears all six matrices (16 rows of
       "0") and writes one harmonic - the frequency through %f,
       the amplitude 1 through %d - into the value matrices and
       their text twins; cosA: additionally sets the row-0 phase
       to 3.1415/2.0 through %f.  Drive every one, and check the
       strings the real controls would show. */
    [(WaveBuilderModule *)module clear: nil];
    int r;
    int m;
    static const char *sixNames[] = {
        "sinHarmonics", "sinAmplitudes", "sinPhases",
        "sinTextHarmonics", "sinTextAmplitudes", "sinTextPhases"
    };
    FakeSinMatrix *six[6] = { harmonics, amplitudes, phases,
                              textHarmonics, textAmplitudes, textPhases };
    for (m = 0; m < 6; m++)
        for (r = 0; r < 16; r += 8)
            {
            char what[80];
            snprintf (what, sizeof what, "clear: %s row %d", sixNames[m], r);
            check ([[ [six[m] cellAtRow: r column: 0] stringValue]
                     isEqualToString: @"0"], what);
            }
    /* GNUstep's @selector is a runtime expression, so the table
       cannot be static - an automatic array holds it. */
    const struct { SEL sel; float freq; } notes[] = {
        { @selector(A:), 440 },
        { @selector(As:), 466.16 },
        { @selector(B:), 493.89 },
        { @selector(C:), 523.24 },
        { @selector(Cs:), 554.36 },
        { @selector(D:), 587.32 },
        { @selector(Ds:), 622.26 },
        { @selector(E:), 659.26 },
        { @selector(F:), 698.46 },
        { @selector(Fs:), 739.98 },
        { @selector(G:), 783.98 },
        { @selector(Gs:), 830.62 }
    };
    int n;
    for (n = 0; n < 12; n++)
        {
        [(WaveBuilderModule *)module performSelector: notes[n].sel
                                       withObject: nil];
        NSString *freqStr =
            [NSString stringWithFormat: @"%f", notes[n].freq];
        char what[80];
        for (m = 0; m < 6; m++)
            {
            NSString *expect = (m == 0 || m == 3) ? freqStr
                : (m == 1 || m == 4) ? @"1" : @"0";
            snprintf (what, sizeof what, "note %d: %s row 0",
                      n, sixNames[m]);
            check ([[ [six[m] cellAtRow: 0 column: 0] stringValue]
                     isEqualToString: expect], what);
            }
        snprintf (what, sizeof what, "note %d: the clear held on row 15", n);
        check ([[ [harmonics cellAtRow: 15 column: 0] stringValue]
                 isEqualToString: @"0"], what);
        }
    /* cosA: the preset that also sets the phase. */
    [(WaveBuilderModule *)module cosA: nil];
    for (m = 0; m < 6; m++)
        {
        NSString *expect = (m == 0 || m == 3) ? @"440.000000"
            : (m == 1 || m == 4) ? @"1" : @"1.570750";
        char what[80];
        snprintf (what, sizeof what, "cosA: %s row 0", sixNames[m]);
        check ([[ [six[m] cellAtRow: 0 column: 0] stringValue]
                 isEqualToString: expect], what);
        }
}

/*
A fresh real FFTController from the loaded bundle, its four
outlet ivars (the two graph views, the minimum-dB field and the
decibel button) filled with fakes the same way the gorm wires
them, and its islinear set to the branch under test (the
alloc-zeroed default is 0, the decibel path; 1 is the linear
path).  Returns the controller.
*/
static FFTController *freshFftController (BOOL linear)
{
    Class c = NSClassFromString (@"FFTController");
    FFTController *ctl = [[[c alloc] init] autorelease];
    check (ctl != nil, "a real FFTController instantiates");
    if (ctl == nil)
        return nil;
    Ivar iv;
    iv = class_getInstanceVariable ([ctl class], "freqview");
    object_setIvar (ctl, iv, [[[FakeFftGraph alloc] init] autorelease]);
    iv = class_getInstanceVariable ([ctl class], "phasview");
    object_setIvar (ctl, iv, [[[FakeFftGraph alloc] init] autorelease]);
    iv = class_getInstanceVariable ([ctl class], "minimumdbfield");
    object_setIvar (ctl, iv, [[[FakeFftField alloc] init] autorelease]);
    iv = class_getInstanceVariable ([ctl class], "decibelButton");
    object_setIvar (ctl, iv,
        [[[FakeFftButton alloc] initWithValue: 1] autorelease]);
    writeSizedIvar (ctl, "islinear", linear ? 1 : 0);
    return ctl;
}

/*
The doFFT: contract on one case: a real in-memory Snd of the
case's format (mono, 44.1k - the one shape the 1998 method
accepts without its modal conversion prompt) in a real SndView
with the case's selection, through the module's doFFT: to a
fresh real FFTController.  The expectation recomputes the same
real Snd performFFTFromSoundData: the controller calls (the
1998 Snd(ModuleSound) category, compiled into this tool from
the app's Source/ModuleSound.m plus the 1998 fft.c core), then
the 1998 f1/f2/p1 split and the minimum-dB floor, and checks
the controller's buffers, the minimum-dB field and the graph
setTo: / setReals: / display calls against it.
*/
static void testFftDrawFFT (id module, SndSampleFormat fmt, int frames,
                            int selStart, int selLen, BOOL linear)
{
    const char *name =
        [SndFormatName (fmt, NO) cStringUsingEncoding: NSASCIIStringEncoding];
    printf ("== doFFT: %s mono 44.1k, %d frames, selection (%d,%d), %s\n",
            name, frames, selStart, selLen, linear ? "linear" : "decibel");

    Snd *snd = [[[Snd alloc] initWithFormat: fmt
                               channelCount: 1
                                   frames: frames
                             samplingRate: 44100.0f] autorelease];
    check (snd != nil && [snd lengthInSampleFrames] == (unsigned long)frames
             && [snd channelCount] == 1, "the source Snd is mono 44.1k");
    if (snd == nil)
        return;
    fillPattern (snd, 0);

    SndView *view = [[[SndView alloc]
        initWithFrame: NSMakeRect (0, 0, 320, 200)] autorelease];
    [view setSound: snd];
    [view setSelection: selStart size: selLen];

    FFTController *ctl = freshFftController (linear);
    if (ctl == nil)
        return;
    FakeFftController *mc = [[[FakeFftController alloc]
        initWithSound: snd soundView: view] autorelease];
    object_setIvar (module,
        class_getInstanceVariable ([module class], "moduleController"), mc);
    object_setIvar (module,
        class_getInstanceVariable ([module class], "fftController"), ctl);

    /* The expectation: the same real performFFTFromSoundData: the
       controller calls, then the 1998 split (f1 the amplitude of
       the positive half, f2 the dB-mapped copy, p1 the phase of
       that half) and the minimum-dB floor. */
    int n = [Snd nextPositivePowerOfTwo: selLen];
    check (n >= selLen && (n & (n - 1)) == 0,
           "the fft length is a power of two");
    float *f = (float*)malloc (sizeof (float) * n * 2);
    check ([Snd performFFTFromSoundData:[snd bytes]:selStart:selLen:
            [snd dataFormat]:[snd channelCount]
            toFFTData:f:n] == 1, "the expectation FFT ran");
    int half = n / 2;
    float *f1e = (float*)malloc (sizeof (float) * half);
    float *f2e = (float*)malloc (sizeof (float) * half);
    float *p1e = (float*)malloc (sizeof (float) * half);
    float minDb = 0.00001;
    int x;
    for (x = 0; x < half; x++)
        {
        f1e[x] = f[x*2+n];
        f2e[x] = 20 * log (f[x*2+n] < 0 ? -(FLT_MAX)
                          : (f[x*2+n] > 1 ? 1 : f[x*2+n]));
        p1e[x] = f[x*2+n+1];
        if (f2e[x] < minDb)
            minDb = f2e[x];
        }
    free (f);

    id ret = [(FFTModule *)module doFFT: nil];
    check (ret == module, "doFFT: returns self");

    check (readSizedIvar (ctl, "n") == n,
           "the n ivar is the next power of two");
    float *f1 = (float*)object_getIvar (ctl,
        class_getInstanceVariable ([ctl class], "f1"));
    float *f2 = (float*)object_getIvar (ctl,
        class_getInstanceVariable ([ctl class], "f2"));
    float *p1 = (float*)object_getIvar (ctl,
        class_getInstanceVariable ([ctl class], "p1"));
    check (f1 != nil && memcmp (f1, f1e, sizeof (float)*half) == 0,
           "f1 matches the 1998 linear split");
    check (f2 != nil && memcmp (f2, f2e, sizeof (float)*half) == 0,
           "f2 matches the 1998 dB mapping");
    check (p1 != nil && memcmp (p1, p1e, sizeof (float)*half) == 0,
           "p1 matches the 1998 phase split");

    FakeFftField *db = readObjIvar (ctl, "minimumdbfield");
    check ([db setValueCount] == 1, "the minimum-dB field was set");
    check ([db floatValue] == (double)minDb,
           "the minimum-dB field holds the floor");

    FakeFftGraph *freq = readObjIvar (ctl, "freqview");
    FakeFftGraph *phas = readObjIvar (ctl, "phasview");
    check ([freq setToCount] == 1 && [freq realsCount] == 1
             && [freq displayCount] == 1,
           "the frequency graph was set and drawn");
    check ([phas setToCount] == 1 && [phas realsCount] == 1
             && [phas displayCount] == 1,
           "the phase graph was set and drawn");
    /* The phase graph's range is branch-independent. */
    check ([phas toMax] == (float)3.141592653589793
             && [phas toMin] == (float)(-3.141592653589793)
             && [phas stretchToMax] == NO && [phas stretchToMin] == NO
             && [phas xScale] == 22050
             && [phas format] == DISCRETEGRAPHVIEW_FORMAT_CENTERED_ON_ZERO,
           "the phase graph range is +/-pi centered on zero");
    check ([phas realsSize] == half
             && memcmp ([phas reals], p1e, sizeof (float)*half) == 0,
           "the phase graph plots p1");
    /* The frequency graph's range follows the branch, its data the
       matching buffer. */
    if (linear)
        {
        check ([freq toMax] == 1.0f && [freq toMin] == 0.0f
                 && [freq stretchToMax] == YES
                 && [freq stretchToMin] == NO
                 && [freq xScale] == 22050
                 && [freq format] == DISCRETEGRAPHVIEW_FORMAT_HISTOGRAM,
               "the linear frequency range is 0..1 stretched");
        }
    else
        {
        float expectMin = minDb < 0 ? minDb : (float)30;
        check ([freq toMax] == 0.0f && [freq toMin] == expectMin
                 && [freq stretchToMax] == YES
                 && [freq stretchToMin] == NO
                 && [freq xScale] == 22050
                 && [freq format] == DISCRETEGRAPHVIEW_FORMAT_HISTOGRAM,
               "the decibel frequency range is the minimum-dB floor");
        }
    check ([freq realsSize] == half
             && memcmp ([freq reals], linear ? f1e : f2e,
                        sizeof (float)*half) == 0,
           "the frequency graph plots the branch's buffer");
    free (f1e);
    free (f2e);
    free (p1e);
}

static void runFFT (Class principal)
{
    /* The menu tree the app's Modules menu is built from: one
       leaf, the 1998 three-dot name, targeting the module. */
    id module = [[principal alloc] init];
    check (module != nil, "module instantiation");
    id root = [module getModuleMenuNode];
    check (root != nil, "root menu node");
    check (root != nil && [root numSubmenus] == 1,
           "root has exactly one submenu");
    id leaf = root != nil ? [root getSubmenu: 0] : nil;
    check (leaf != nil && [leaf isLeafNode], "leaf node");
    check (leaf != nil
             && [[leaf getNameAsString] isEqualToString: @"FFT..."],
           "leaf is named FFT...");
    check (leaf != nil
             && [NSStringFromSelector ([leaf getMessage])
                 isEqualToString: @"showFFTPanel:"],
           "leaf targets showFFTPanel:");
    check (leaf != nil && [leaf getReceiver] == module,
           "leaf targets the module");

    /* The module's four outlet ivars and the one-byte nib_loaded
       flag: all exist and start un-wired (the gorm wires them
       when the real panel loads - the resoundmenu --perform
       probe). */
    Ivar mcIvar = class_getInstanceVariable ([module class],
                                             "moduleController");
    check (mcIvar != NULL, "moduleController ivar (for the DSP cases)");
    static const char *outletNames[] = {
        "fftPanel", "fftController", "x", "y"
    };
    int o;
    for (o = 0; o < 4; o++)
        {
        char what[80];
        snprintf (what, sizeof what, "%s ivar exists", outletNames[o]);
        check (class_getInstanceVariable ([module class], outletNames[o])
               != NULL, what);
        snprintf (what, sizeof what, "%s ivar starts nil", outletNames[o]);
        check (readObjIvar (module, outletNames[o]) == nil, what);
        }
    check (readSizedIvar (module, "nib_loaded") == 0,
           "nib_loaded starts unset");

    /* The doFFT: matrix: the five 1998 data formats the 1998
       method accepts (all five - the guard only requires mono
       44.1k), whole-sound and partial selections, and both the
       decibel (the alloc-zeroed islinear default) and the linear
       branch. */
    int c;
    for (c = 0; c < 5; c++)
        {
        testFftDrawFFT (module, (SndSampleFormat)dspFormats[c],
                        512, 0, 512, NO);
        testFftDrawFFT (module, (SndSampleFormat)dspFormats[c],
                        512, 64, 256, NO);
        }
    testFftDrawFFT (module, SND_FORMAT_LINEAR_16, 512, 0, 512, YES);
    testFftDrawFFT (module, SND_FORMAT_LINEAR_16, 512, 64, 256, YES);

    /* The panel: the showFFTPanel: contract with the outlets as
       fakes and the one-byte nib_loaded flag pre-set to 1
       (skipping the nib load, which needs a display and runs in
       the app; the resoundmenu --perform probe drives it there
       for real).  The 1998 method hands the two axis fields to
       the controller's setDelegates: (which forwards them to the
       frequency graph's cursor) and orders the panel key and
       front. */
    FakeFftGraph *freq = [[[FakeFftGraph alloc] init] autorelease];
    FakeFftField *db = [[[FakeFftField alloc] init] autorelease];
    FakeFftButton *button =
        [[[FakeFftButton alloc] initWithValue: 1] autorelease];
    FakeFftPanel *panel = [[[FakeFftPanel alloc] init] autorelease];
    FakeFftAxis *xaxis = [[[FakeFftAxis alloc] init] autorelease];
    FakeFftAxis *yaxis = [[[FakeFftAxis alloc] init] autorelease];
    object_setIvar (module,
        class_getInstanceVariable ([module class], "fftPanel"), panel);
    object_setIvar (module, class_getInstanceVariable ([module class],
                                                       "x"), xaxis);
    object_setIvar (module, class_getInstanceVariable ([module class],
                                                       "y"), yaxis);
    writeSizedIvar (module, "nib_loaded", 1);

    /* A fresh real controller (no drawFFT yet) receives the
       panel's fakes; the module's fftController outlet points at
       it. */
    FFTController *ctl = freshFftController (NO);
    if (ctl == nil)
        return;
    object_setIvar (ctl, class_getInstanceVariable ([ctl class],
                                                    "freqview"), freq);
    object_setIvar (ctl, class_getInstanceVariable ([ctl class],
                                                    "minimumdbfield"), db);
    object_setIvar (ctl, class_getInstanceVariable ([ctl class],
                                                    "decibelButton"), button);
    object_setIvar (module, class_getInstanceVariable ([module class],
                                                       "fftController"), ctl);

    id ret = [(FFTModule *)module showFFTPanel: nil];
    check (ret == module, "showFFTPanel: returns self");
    check ([panel keyFrontCount] == 1,
           "showFFTPanel: ordered the panel key and front");
    check ([freq cursorCount] == 1 && [freq cursorX] == xaxis
             && [freq cursorY] == yaxis,
           "showFFTPanel: handed the axis fields to the graph cursor");
    check (readSizedIvar (module, "nib_loaded") == 1,
           "nib_loaded stays set (no reload)");
    [(FFTModule *)module showFFTPanel: nil];
    check ([panel keyFrontCount] == 2, "showFFTPanel: is repeatable");
    check ([freq cursorCount] == 2,
           "showFFTPanel: re-hands the delegates each time");

    /* The toggle: the 1998 button reads its intValue and flips
       islinear, then redraws.  With no drawFFT yet the f1/f2
       ivars are NULL, so redrawGraphs: is a no-op (the 1998
       guard) - the graphs stay untouched, and the islinear flip
       is the only effect. */
    check ([freq setToCount] == 0, "no graphs drawn before any doFFT:");
    [(FFTController *)ctl toggleLinearAndDecibel: nil];
    check (readSizedIvar (ctl, "islinear") == 0,
           "toggle with the button at 1 lands on decibel (islinear 0)");
    check ([freq setToCount] == 0,
           "toggle without a drawn FFT redraws nothing");
    [button setIntValue: 0];
    [(FFTController *)ctl toggleLinearAndDecibel: nil];
    check (readSizedIvar (ctl, "islinear") == 1,
           "toggle with the button at 0 lands on linear (islinear 1)");
    check ([freq setToCount] == 0, "the redraw still sees no buffers");

    /* A full redraw with a drawn FFT: run doFFT: once to fill the
       buffers, then redraw and check the branch follows islinear. */
    Snd *snd = [[[Snd alloc]
        initWithFormat: SND_FORMAT_LINEAR_16 channelCount: 1 frames: 128
        samplingRate: 44100.0f] autorelease];
    if (snd == nil)
        return;
    fillPattern (snd, 0);
    SndView *view = [[[SndView alloc]
        initWithFrame: NSMakeRect (0, 0, 320, 200)] autorelease];
    [view setSound: snd];
    [view setSelection: 0 size: 128];
    FakeFftController *mc = [[[FakeFftController alloc]
        initWithSound: snd soundView: view] autorelease];
    object_setIvar (module, mcIvar, mc);
    [(FFTModule *)module doFFT: nil];
    check ([freq setToCount] == 1 && [freq realsCount] == 1,
           "doFFT: drew the graphs (the current islinear branch)");

    int setBefore = [freq setToCount];
    [(FFTController *)ctl redrawGraphs: nil];
    check ([freq setToCount] == setBefore + 1,
           "redrawGraphs: re-drew the frequency graph");
    check ([freq toMax] == 1.0f,
           "redrawGraphs: used the linear range (islinear 1)");
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

static void runEnvelope (Class principal)
{
    /* The menu tree the app's Modules menu is built from. */
    id module = [[principal alloc] init];
    check (module != nil, "module instantiation");
    id root = [module getModuleMenuNode];
    check (root != nil, "root menu node");
    check (root != nil && [root numSubmenus] == 1, "root has exactly one submenu");
    id leaf = root != nil ? [root getSubmenu: 0] : nil;
    check (leaf != nil && [leaf isLeafNode], "leaf node");
    check (leaf != nil && [[leaf getNameAsString] isEqualToString: @"Envelope"],
           "leaf is named Envelope");
    check (leaf != nil && [NSStringFromSelector ([leaf getMessage]) isEqualToString: @"showEnvelopePanel:"],
           "leaf targets showEnvelopePanel:");
    check (leaf != nil && [leaf getReceiver] == module, "leaf targets the module");

    /* The controller ivar (inherited from Module) and the six panel
       outlet ivars declared by the 1998 header.  (The gorm connects
       five of the six - the 1998 nib leaves applyToAllButton
       unconnected - but the header declares the ivar either way.) */
    Ivar ivar = class_getInstanceVariable ([module class], "moduleController");
    check (ivar != NULL, "moduleController ivar (for the DSP cases)");
    static const char *outletNames[] = {
        "envelopePanel", "applyButton", "inOutMatrix",
        "applyToLeftButton", "applyToRightButton", "applyToAllButton"
    };
    int o;
    for (o = 0; o < 6; o++)
    {
        char what[80];
        snprintf (what, sizeof what, "%s ivar", outletNames[o]);
        check (class_getInstanceVariable ([module class], outletNames[o]) != NULL, what);
    }

    /* showEnvelopePanel: with the outlets pre-set to the fakes (a
       real panel load needs a display - the app-side half is the
       resoundmenu --perform probe). */
    testShowEnvelopePanel (module, ivar, 2);
    testShowEnvelopePanel (module, ivar, 1);

    /* The fade DSP: the five 1998 formats, mono and stereo, a
       whole-sound selection fading in on both channels, then partial
       50-frame selections, one channel each, in and out. */
    int c;
    int ch;
    for (c = 0; c < 5; c++)
        for (ch = 1; ch <= 2; ch++)
            testEnvelope (module, ivar, (SndSampleFormat)dspFormats[c], ch,
                          YES, 0, 200, 1, 1, 200);
    for (c = 0; c < 5; c++)
        for (ch = 1; ch <= 2; ch++)
            testEnvelope (module, ivar, (SndSampleFormat)dspFormats[c], ch,
                          YES, 10, 50, 1, 0, 200);
    for (c = 0; c < 5; c++)
        for (ch = 1; ch <= 2; ch++)
            testEnvelope (module, ivar, (SndSampleFormat)dspFormats[c], ch,
                          NO, 10, 50, 0, 1, 200);

    /* And the 1998 LOTS_OF_SAMPLES branch: a 400001-frame mono sound
       (just past 400000 * 1) consults runLongTimePanel before the
       DSP runs. */
    for (c = 0; c < 5; c++)
        testEnvelope (module, ivar, (SndSampleFormat)dspFormats[c], 1,
                      YES, 0, 400001, 1, 1, 400001);
    for (c = 0; c < 5; c++)
        testEnvelope (module, ivar, (SndSampleFormat)dspFormats[c], 1,
                      NO, 0, 400001, 1, 1, 400001);
}

/*
The Math module's per-element transforms, mirrored from the ported
MATH_INDEPENDENT arms - the same per-format temporaries (the signed
short of the mu-law decode, the char of the 8-bit, the short of the
16-bit, the float, the double), the same operation, the same
assignment, the same loop bounds - so the expected buffer is exactly
what the 1998-faithful module code computes on the same input.  The
mu-law arm decodes through SndKit's SndMuLawToLinear /
SndLinearToMuLaw pair (the ported rename of the 1998 SND*
conversion pair); the multiply arm below is the 1998 slider percent
with the per-format hi/low clip pair, the shift arm the 1998 slider
times the format's hi-clip, maximize: the 1998 max scan to the
percent field, and reverse the 1998 whole-selection reversal plus
the stereo pair swap.
*/
static void mathExpectAbs (void *buf, unsigned int first, unsigned int len,
                           int ch, SndSampleFormat fmt)
{
    switch (fmt)
        {
        case SND_FORMAT_MULAW_8:
            {
            char *d = (char *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                signed short tempsnd = SndMuLawToLinear ((unsigned char)d[x]);
                tempsnd = (signed short)fabs ((double)tempsnd);
                d[x] = SndLinearToMuLaw (tempsnd);
                }
            } break;
        case SND_FORMAT_LINEAR_8:
            {
            char *d = (char *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                char tempsnd = d[x];
                tempsnd = (char)fabs ((double)tempsnd);
                d[x] = tempsnd;
                }
            } break;
        case SND_FORMAT_LINEAR_16:
            {
            signed short *d = (signed short *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                signed short tempsnd = d[x];
                tempsnd = (signed short)fabs ((double)tempsnd);
                d[x] = tempsnd;
                }
            } break;
        case SND_FORMAT_FLOAT:
            {
            float *d = (float *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                float tempsnd = d[x];
                tempsnd = (float)fabs ((double)tempsnd);
                d[x] = tempsnd;
                }
            } break;
        case SND_FORMAT_DOUBLE:
            {
            double *d = (double *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                double tempsnd = d[x];
                tempsnd = (double)fabs ((double)tempsnd);
                d[x] = tempsnd;
                }
            } break;
        default:
            break;
        }
}

static void mathExpectInvert (void *buf, unsigned int first, unsigned int len,
                              int ch, SndSampleFormat fmt)
{
    switch (fmt)
        {
        case SND_FORMAT_MULAW_8:
            {
            char *d = (char *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                signed short tempsnd = SndMuLawToLinear ((unsigned char)d[x]);
                tempsnd = (signed short)(-tempsnd);
                d[x] = SndLinearToMuLaw (tempsnd);
                }
            } break;
        case SND_FORMAT_LINEAR_8:
            {
            char *d = (char *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                char tempsnd = d[x];
                tempsnd = (char)(-tempsnd);
                d[x] = tempsnd;
                }
            } break;
        case SND_FORMAT_LINEAR_16:
            {
            signed short *d = (signed short *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                signed short tempsnd = d[x];
                tempsnd = (signed short)(-tempsnd);
                d[x] = tempsnd;
                }
            } break;
        case SND_FORMAT_FLOAT:
            {
            float *d = (float *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                float tempsnd = d[x];
                tempsnd = (float)(-tempsnd);
                d[x] = tempsnd;
                }
            } break;
        case SND_FORMAT_DOUBLE:
            {
            double *d = (double *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                double tempsnd = d[x];
                tempsnd = (double)(-tempsnd);
                d[x] = tempsnd;
                }
            } break;
        default:
            break;
        }
}

static void mathExpectMultiply (void *buf, unsigned int first, unsigned int len,
                                int ch, SndSampleFormat fmt, float slider)
{
    switch (fmt)
        {
        case SND_FORMAT_MULAW_8:
            {
            char *d = (char *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                signed short tempsnd = SndMuLawToLinear ((unsigned char)d[x]);
                signed short hi_clip = SHRT_MAX;
                signed short low_clip = SHRT_MIN;
                tempsnd = (signed short)(tempsnd*slider/100 > hi_clip ? hi_clip :
                    (tempsnd*slider/100 < low_clip ? low_clip : tempsnd*slider/100));
                d[x] = SndLinearToMuLaw (tempsnd);
                }
            } break;
        case SND_FORMAT_LINEAR_8:
            {
            char *d = (char *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                char tempsnd = d[x];
                char hi_clip = CHAR_MAX;
                char low_clip = CHAR_MIN;
                tempsnd = (char)(tempsnd*slider/100 > hi_clip ? hi_clip :
                    (tempsnd*slider/100 < low_clip ? low_clip : tempsnd*slider/100));
                d[x] = tempsnd;
                }
            } break;
        case SND_FORMAT_LINEAR_16:
            {
            signed short *d = (signed short *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                signed short tempsnd = d[x];
                signed short hi_clip = SHRT_MAX;
                signed short low_clip = SHRT_MIN;
                tempsnd = (signed short)(tempsnd*slider/100 > hi_clip ? hi_clip :
                    (tempsnd*slider/100 < low_clip ? low_clip : tempsnd*slider/100));
                d[x] = tempsnd;
                }
            } break;
        case SND_FORMAT_FLOAT:
            {
            float *d = (float *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                float tempsnd = d[x];
                float hi_clip = 1.0;
                float low_clip = -(1.0);
                tempsnd = (float)(tempsnd*slider/100 > hi_clip ? hi_clip :
                    (tempsnd*slider/100 < low_clip ? low_clip : tempsnd*slider/100));
                d[x] = tempsnd;
                }
            } break;
        case SND_FORMAT_DOUBLE:
            {
            double *d = (double *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                double tempsnd = d[x];
                double hi_clip = 1.0;
                double low_clip = -(1.0);
                tempsnd = (double)(tempsnd*slider/100 > hi_clip ? hi_clip :
                    (tempsnd*slider/100 < low_clip ? low_clip : tempsnd*slider/100));
                d[x] = tempsnd;
                }
            } break;
        default:
            break;
        }
}

static void mathExpectShift (void *buf, unsigned int first, unsigned int len,
                             int ch, SndSampleFormat fmt, float slider)
{
    switch (fmt)
        {
        case SND_FORMAT_MULAW_8:
            {
            char *d = (char *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                signed short tempsnd = SndMuLawToLinear ((unsigned char)d[x]);
                signed short hi_clip = SHRT_MAX;
                signed short low_clip = SHRT_MIN;
                tempsnd = (signed short)(tempsnd+(slider*hi_clip) > hi_clip ? hi_clip :
                    (tempsnd+(slider*hi_clip) < low_clip ? low_clip :
                     tempsnd+(slider*hi_clip)));
                d[x] = SndLinearToMuLaw (tempsnd);
                }
            } break;
        case SND_FORMAT_LINEAR_8:
            {
            char *d = (char *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                char tempsnd = d[x];
                char hi_clip = CHAR_MAX;
                char low_clip = CHAR_MIN;
                tempsnd = (char)(tempsnd+(slider*hi_clip) > hi_clip ? hi_clip :
                    (tempsnd+(slider*hi_clip) < low_clip ? low_clip :
                     tempsnd+(slider*hi_clip)));
                d[x] = tempsnd;
                }
            } break;
        case SND_FORMAT_LINEAR_16:
            {
            signed short *d = (signed short *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                signed short tempsnd = d[x];
                signed short hi_clip = SHRT_MAX;
                signed short low_clip = SHRT_MIN;
                tempsnd = (signed short)(tempsnd+(slider*hi_clip) > hi_clip ? hi_clip :
                    (tempsnd+(slider*hi_clip) < low_clip ? low_clip :
                     tempsnd+(slider*hi_clip)));
                d[x] = tempsnd;
                }
            } break;
        case SND_FORMAT_FLOAT:
            {
            float *d = (float *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                float tempsnd = d[x];
                float hi_clip = 1.0;
                float low_clip = -(1.0);
                tempsnd = (float)(tempsnd+(slider*hi_clip) > hi_clip ? hi_clip :
                    (tempsnd+(slider*hi_clip) < low_clip ? low_clip :
                     tempsnd+(slider*hi_clip)));
                d[x] = tempsnd;
                }
            } break;
        case SND_FORMAT_DOUBLE:
            {
            double *d = (double *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                double tempsnd = d[x];
                double hi_clip = 1.0;
                double low_clip = -(1.0);
                tempsnd = (double)(tempsnd+(slider*hi_clip) > hi_clip ? hi_clip :
                    (tempsnd+(slider*hi_clip) < low_clip ? low_clip :
                     tempsnd+(slider*hi_clip)));
                d[x] = tempsnd;
                }
            } break;
        default:
            break;
        }
}

/* The 1998 max scan per format arm, the same as the module's
   maximize: - the same temporaries (including the 1998 char
   fingerprint of the 8-bit arm), the same comparison, and the same
   field expression the module sends to setFloatValue:. */
static float mathExpectMaximize (void *buf, unsigned int first, unsigned int len,
                                 int ch, SndSampleFormat fmt)
{
    switch (fmt)
        {
        case SND_FORMAT_MULAW_8:
            {
            char *d = (char *)buf;
            int x;
            signed short hi_clip = SHRT_MAX;
            signed short max = 0;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                signed short tempsnd = SndMuLawToLinear ((unsigned char)d[x]);
                if (max < abs (tempsnd)) max = (float)abs (tempsnd);
                }
            return ((float)hi_clip) / ((float)max) * 100.0;
            }
        case SND_FORMAT_LINEAR_8:
            {
            char *d = (char *)buf;
            int x;
            char hi_clip = CHAR_MAX;
            char max = 0;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                if (max < abs (d[x])) max = (float)abs (d[x]);
                }
            return ((float)hi_clip) / ((float)max) * 100.0;
            }
        case SND_FORMAT_LINEAR_16:
            {
            signed short *d = (signed short *)buf;
            int x;
            signed short hi_clip = SHRT_MAX;
            signed short max = 0;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                if (max < abs (d[x])) max = (float)abs (d[x]);
                }
            return ((float)hi_clip) / ((float)max) * 100.0;
            }
        case SND_FORMAT_FLOAT:
            {
            float *d = (float *)buf;
            int x;
            float hi_clip = 1.0;
            float max = 0;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                if (max < fabs (d[x])) max = fabs (d[x]);
                }
            return ((float)hi_clip) / ((float)max) * 100.0;
            }
        case SND_FORMAT_DOUBLE:
            {
            double *d = (double *)buf;
            int x;
            double hi_clip = 1.0;
            double max = 0;
            for (x = first * ch; x < (first + len) * ch; x++)
                {
                if (max < fabs (d[x])) max = fabs (d[x]);
                }
            return ((float)hi_clip) / ((float)max) * 100.0;
            }
        default:
            return 0.0f;
        }
}

/* The 1998 whole-selection reversal, arm for arm - the same
   half-loop with the 1998 index arithmetic, then the same stereo
   pair swap for a two-channel sound. */
static void mathExpectReverse (void *buf, unsigned int first, unsigned int len,
                               int ch, SndSampleFormat fmt)
{
    switch (fmt)
        {
        case SND_FORMAT_MULAW_8:
        case SND_FORMAT_LINEAR_8:
            {
            char *d = (char *)buf;
            int x;
            char trader = 0;
            for (x = first * ch; x < (first + len / 2) * ch; x++)
                {
                trader = d[x];
                d[x] = d[(first + len) * ch - x - 1 + first * ch];
                d[(first + len) * ch - x - 1 + first * ch] = trader;
                }
            if (ch == 2)
                for (x = first * ch; x < (first + len) * ch; x += 2)
                    {
                    trader = d[x];
                    d[x] = d[x + 1];
                    d[x + 1] = trader;
                    }
            } break;
        case SND_FORMAT_LINEAR_16:
            {
            signed short *d = (signed short *)buf;
            int x;
            signed short trader = 0;
            for (x = first * ch; x < (first + len / 2) * ch; x++)
                {
                trader = d[x];
                d[x] = d[(first + len) * ch - x - 1 + first * ch];
                d[(first + len) * ch - x - 1 + first * ch] = trader;
                }
            if (ch == 2)
                for (x = first * ch; x < (first + len) * ch; x += 2)
                    {
                    trader = d[x];
                    d[x] = d[x + 1];
                    d[x + 1] = trader;
                    }
            } break;
        case SND_FORMAT_FLOAT:
            {
            float *d = (float *)buf;
            int x;
            float trader = 0;
            for (x = first * ch; x < (first + len / 2) * ch; x++)
                {
                trader = d[x];
                d[x] = d[(first + len) * ch - x - 1 + first * ch];
                d[(first + len) * ch - x - 1 + first * ch] = trader;
                }
            if (ch == 2)
                for (x = first * ch; x < (first + len) * ch; x += 2)
                    {
                    trader = d[x];
                    d[x] = d[x + 1];
                    d[x + 1] = trader;
                    }
            } break;
        case SND_FORMAT_DOUBLE:
            {
            double *d = (double *)buf;
            int x;
            double trader = 0;
            for (x = first * ch; x < (first + len / 2) * ch; x++)
                {
                trader = d[x];
                d[x] = d[(first + len) * ch - x - 1 + first * ch];
                d[(first + len) * ch - x - 1 + first * ch] = trader;
                }
            if (ch == 2)
                for (x = first * ch; x < (first + len) * ch; x += 2)
                    {
                    trader = d[x];
                    d[x] = d[x + 1];
                    d[x + 1] = trader;
                    }
            } break;
        default:
            break;
        }
}

static void testMathAbs (id module, Ivar mcIvar, SndSampleFormat fmt, int ch,
                         unsigned int first, unsigned int len)
{
    const char *name = [SndFormatName (fmt, NO) cStringUsingEncoding: NSASCIIStringEncoding];
    printf ("== math: absIt: %s, %d channel(s), selection (%u,%u)\n",
            name, ch, first, len);

    Snd *snd = [[[Snd alloc] initWithFormat: fmt
                                channelCount: ch
                                    frames: 200
                              samplingRate: 44100.0f] autorelease];
    check (snd != nil && [snd lengthInSampleFrames] == 200, "in-memory Snd");
    fillPattern (snd, 0);
    long size = [snd dataSize];
    unsigned char *before = malloc ((size_t)size);
    memcpy (before, [snd bytes], (size_t)size);

    FakeMathView *view = [[[FakeMathView alloc] initWithSound: snd] autorelease];
    [view setSelection: first size: len];
    FakeMathController *mc =
        [[[FakeMathController alloc] initWithSound: snd soundView: view] autorelease];
    object_setIvar (module, mcIvar, mc);

    /* The module's 1998 fall-through: a zero-length selection
       becomes the whole sound. */
    unsigned int effFirst = first, effLen = len;
    if (effLen == 0)
        {
        effFirst = 0;
        effLen = 200;
        }

    id ret = [(MathModule *)module absIt: nil];

    check (ret == module, "absIt: returns self");
    check ([mc stopCount] == 1, "absIt: stopped the playback");
    check ([mc soundChangedCount] == 1, "absIt: reported the sound changed");
    check ([snd dataFormat] == fmt && [snd channelCount] == ch
       && [snd lengthInSampleFrames] == 200,
            "the sound keeps its format, channels and length");

    unsigned char *expected = malloc ((size_t)size);
    memcpy (expected, before, (size_t)size);
    mathExpectAbs (expected, effFirst, effLen, ch, fmt);
    check (memcmp ([snd bytes], expected, (size_t)size) == 0,
            "the buffer matches the 1998 DSP arithmetic");
    free (before);
    free (expected);
}

static void testMathInvert (id module, Ivar mcIvar, SndSampleFormat fmt, int ch,
                            unsigned int first, unsigned int len)
{
    const char *name = [SndFormatName (fmt, NO) cStringUsingEncoding: NSASCIIStringEncoding];
    printf ("== math: invertIt: %s, %d channel(s), selection (%u,%u)\n",
            name, ch, first, len);

    Snd *snd = [[[Snd alloc] initWithFormat: fmt
                                channelCount: ch
                                    frames: 200
                              samplingRate: 44100.0f] autorelease];
    check (snd != nil && [snd lengthInSampleFrames] == 200, "in-memory Snd");
    fillPattern (snd, 0);
    long size = [snd dataSize];
    unsigned char *before = malloc ((size_t)size);
    memcpy (before, [snd bytes], (size_t)size);

    FakeMathView *view = [[[FakeMathView alloc] initWithSound: snd] autorelease];
    [view setSelection: first size: len];
    FakeMathController *mc =
        [[[FakeMathController alloc] initWithSound: snd soundView: view] autorelease];
    object_setIvar (module, mcIvar, mc);

    unsigned int effFirst = first, effLen = len;
    if (effLen == 0)
        {
        effFirst = 0;
        effLen = 200;
        }

    id ret = [(MathModule *)module invertIt: nil];

    check (ret == module, "invertIt: returns self");
    check ([mc stopCount] == 1, "invertIt: stopped the playback");
    check ([mc soundChangedCount] == 1, "invertIt: reported the sound changed");
    check ([snd dataFormat] == fmt && [snd channelCount] == ch
       && [snd lengthInSampleFrames] == 200,
            "the sound keeps its format, channels and length");

    unsigned char *expected = malloc ((size_t)size);
    memcpy (expected, before, (size_t)size);
    mathExpectInvert (expected, effFirst, effLen, ch, fmt);
    check (memcmp ([snd bytes], expected, (size_t)size) == 0,
            "the buffer matches the 1998 DSP arithmetic");
    free (before);
    free (expected);
}

static void testMathMultiply (id module, Ivar mcIvar, SndSampleFormat fmt, int ch,
                              unsigned int first, unsigned int len, float slider)
{
    const char *name = [SndFormatName (fmt, NO) cStringUsingEncoding: NSASCIIStringEncoding];
    printf ("== math: multiplyIt: %s, %d channel(s), selection (%u,%u), slider %g\n",
            name, ch, first, len, (double)slider);

    Snd *snd = [[[Snd alloc] initWithFormat: fmt
                                channelCount: ch
                                    frames: 200
                              samplingRate: 44100.0f] autorelease];
    check (snd != nil && [snd lengthInSampleFrames] == 200, "in-memory Snd");
    fillPattern (snd, 0);
    long size = [snd dataSize];
    unsigned char *before = malloc ((size_t)size);
    memcpy (before, [snd bytes], (size_t)size);

    FakeMathView *view = [[[FakeMathView alloc] initWithSound: snd] autorelease];
    [view setSelection: first size: len];
    FakeMathController *mc =
        [[[FakeMathController alloc] initWithSound: snd soundView: view] autorelease];
    object_setIvar (module, mcIvar, mc);
    FakeMathField *field = [[[FakeMathField alloc] initWithFloatValue: slider] autorelease];
    FakeMathScroller *scroller =
        [[[FakeMathScroller alloc] initWithFloatValue: slider] autorelease];
    object_setIvar (module, class_getInstanceVariable ([module class],
                                                       "percentChangeField"), field);
    object_setIvar (module, class_getInstanceVariable ([module class],
                                                       "percentChangeScroller"), scroller);

    unsigned int effFirst = first, effLen = len;
    if (effLen == 0)
        {
        effFirst = 0;
        effLen = 200;
        }

    id ret = [(MathModule *)module multiplyIt: nil];

    check (ret == module, "multiplyIt: returns self");
    check ([mc stopCount] == 1, "multiplyIt: stopped the playback");
    check ([mc soundChangedCount] == 1, "multiplyIt: reported the sound changed");
    check ([snd dataFormat] == fmt && [snd channelCount] == ch
       && [snd lengthInSampleFrames] == 200,
            "the sound keeps its format, channels and length");

    unsigned char *expected = malloc ((size_t)size);
    memcpy (expected, before, (size_t)size);
    mathExpectMultiply (expected, effFirst, effLen, ch, fmt, slider);
    check (memcmp ([snd bytes], expected, (size_t)size) == 0,
            "the buffer matches the 1998 DSP arithmetic");
    free (before);
    free (expected);
}

static void testMathShift (id module, Ivar mcIvar, SndSampleFormat fmt, int ch,
                           unsigned int first, unsigned int len, float slider)
{
    const char *name = [SndFormatName (fmt, NO) cStringUsingEncoding: NSASCIIStringEncoding];
    printf ("== math: shiftIt: %s, %d channel(s), selection (%u,%u), slider %g\n",
            name, ch, first, len, (double)slider);

    Snd *snd = [[[Snd alloc] initWithFormat: fmt
                                channelCount: ch
                                    frames: 200
                              samplingRate: 44100.0f] autorelease];
    check (snd != nil && [snd lengthInSampleFrames] == 200, "in-memory Snd");
    fillPattern (snd, 0);
    long size = [snd dataSize];
    unsigned char *before = malloc ((size_t)size);
    memcpy (before, [snd bytes], (size_t)size);

    FakeMathView *view = [[[FakeMathView alloc] initWithSound: snd] autorelease];
    [view setSelection: first size: len];
    FakeMathController *mc =
        [[[FakeMathController alloc] initWithSound: snd soundView: view] autorelease];
    object_setIvar (module, mcIvar, mc);
    FakeMathSlider *sliderFake =
        [[[FakeMathSlider alloc] initWithFloatValue: slider] autorelease];
    object_setIvar (module, class_getInstanceVariable ([module class],
                                                       "shiftSliderValue"), sliderFake);

    unsigned int effFirst = first, effLen = len;
    if (effLen == 0)
        {
        effFirst = 0;
        effLen = 200;
        }

    id ret = [(MathModule *)module shiftIt: nil];

    check (ret == module, "shiftIt: returns self");
    check ([mc stopCount] == 1, "shiftIt: stopped the playback");
    check ([mc soundChangedCount] == 1, "shiftIt: reported the sound changed");
    check ([snd dataFormat] == fmt && [snd channelCount] == ch
       && [snd lengthInSampleFrames] == 200,
            "the sound keeps its format, channels and length");

    unsigned char *expected = malloc ((size_t)size);
    memcpy (expected, before, (size_t)size);
    mathExpectShift (expected, effFirst, effLen, ch, fmt, slider);
    check (memcmp ([snd bytes], expected, (size_t)size) == 0,
            "the buffer matches the 1998 DSP arithmetic");
    free (before);
    free (expected);
}

static void testMathMaximize (id module, Ivar mcIvar, SndSampleFormat fmt, int ch,
                              unsigned int first, unsigned int len)
{
    const char *name = [SndFormatName (fmt, NO) cStringUsingEncoding: NSASCIIStringEncoding];
    printf ("== math: maximize: %s, %d channel(s), selection (%u,%u)\n",
            name, ch, first, len);

    Snd *snd = [[[Snd alloc] initWithFormat: fmt
                                channelCount: ch
                                    frames: 200
                              samplingRate: 44100.0f] autorelease];
    check (snd != nil && [snd lengthInSampleFrames] == 200, "in-memory Snd");
    fillPattern (snd, 0);
    long size = [snd dataSize];
    unsigned char *before = malloc ((size_t)size);
    memcpy (before, [snd bytes], (size_t)size);

    FakeMathView *view = [[[FakeMathView alloc] initWithSound: snd] autorelease];
    [view setSelection: first size: len];
    FakeMathController *mc =
        [[[FakeMathController alloc] initWithSound: snd soundView: view] autorelease];
    object_setIvar (module, mcIvar, mc);
    FakeMathField *field = [[[FakeMathField alloc] initWithFloatValue: 100.0f] autorelease];
    FakeMathScroller *scroller =
        [[[FakeMathScroller alloc] initWithFloatValue: 100.0f] autorelease];
    object_setIvar (module, class_getInstanceVariable ([module class],
                                                       "percentChangeField"), field);
    object_setIvar (module, class_getInstanceVariable ([module class],
                                                       "percentChangeScroller"), scroller);

    unsigned int effFirst = first, effLen = len;
    if (effLen == 0)
        {
        effFirst = 0;
        effLen = 200;
        }

    id ret = [(MathModule *)module maximize: nil];

    check (ret == module, "maximize: returns self");
    check ([mc stopCount] == 1, "maximize: stopped the playback");
    check ([mc soundChangedCount] == 0, "maximize: leaves the sound alone");
    check ([field floatValue] ==
             mathExpectMaximize ([snd bytes], effFirst, effLen, ch, fmt),
            "maximize: set the field to the format's hi-clip over the max");
    check ([scroller floatValue] == [field floatValue],
            "maximize: matched the scroller to the field");
    check (memcmp ([snd bytes], before, (size_t)size) == 0,
            "maximize: the buffer is untouched");
    free (before);
}

static void testMathReverse (id module, Ivar mcIvar, SndSampleFormat fmt, int ch,
                             unsigned int first, unsigned int len)
{
    const char *name = [SndFormatName (fmt, NO) cStringUsingEncoding: NSASCIIStringEncoding];
    printf ("== math: reverseIt: %s, %d channel(s), selection (%u,%u)\n",
            name, ch, first, len);

    Snd *snd = [[[Snd alloc] initWithFormat: fmt
                                channelCount: ch
                                    frames: 200
                              samplingRate: 44100.0f] autorelease];
    check (snd != nil && [snd lengthInSampleFrames] == 200, "in-memory Snd");
    fillPattern (snd, 0);
    long size = [snd dataSize];
    unsigned char *before = malloc ((size_t)size);
    memcpy (before, [snd bytes], (size_t)size);

    FakeMathView *view = [[[FakeMathView alloc] initWithSound: snd] autorelease];
    [view setSelection: first size: len];
    FakeMathController *mc =
        [[[FakeMathController alloc] initWithSound: snd soundView: view] autorelease];
    object_setIvar (module, mcIvar, mc);

    unsigned int effFirst = first, effLen = len;
    if (effLen == 0)
        {
        effFirst = 0;
        effLen = 200;
        }

    id ret = [(MathModule *)module reverseIt: nil];

    check (ret == module, "reverseIt: returns self");
    check ([mc stopCount] == 1, "reverseIt: stopped the playback");
    check ([mc soundChangedCount] == 1, "reverseIt: reported the sound changed");
    check ([snd dataFormat] == fmt && [snd channelCount] == ch
       && [snd lengthInSampleFrames] == 200,
            "the sound keeps its format, channels and length");

    unsigned char *expected = malloc ((size_t)size);
    memcpy (expected, before, (size_t)size);
    mathExpectReverse (expected, effFirst, effLen, ch, fmt);
    check (memcmp ([snd bytes], expected, (size_t)size) == 0,
            "the buffer matches the 1998 reversal (and the stereo swap)");
    free (before);
    free (expected);
}

static void runMath (Class principal)
{
    /* The menu tree the app's Modules menu is built from: the 1998
       init builds an "Amplitude" submenu - the volume and the
       vertical-shift panel loaders first, then the invert and the
       abs transform (the 1998 addSubmenu order: volume, shift,
       invert, abs) - plus a top-level "Reverse" leaf, every target
       the module itself. */
    id module = [[principal alloc] init];
    check (module != nil, "module instantiation");
    id root = [module getModuleMenuNode];
    check (root != nil, "root menu node");
    check (root != nil && [root numSubmenus] == 2,
           "root has exactly two children");
    id amp = root != nil ? [root getSubmenu: 0] : nil;
    check (amp != nil && ![amp isLeafNode]
             && [[amp getNameAsString] isEqualToString: @"Amplitude"],
           "the first child is the Amplitude submenu");
    check (amp != nil && [amp numSubmenus] == 4,
           "Amplitude holds exactly four leaves");
    static const char *leafNames[] = {
        "Change Amplitude...", "Vertical Shift...", "Invert",
        "AbsoluteValue"
    };
    static const char *leafTargets[] = {
        "showMultiplyPanel:", "showShiftPanel:", "invertIt:", "absIt:"
    };
    int i;
    for (i = 0; i < 4; i++)
        {
        char what[80];
        id leaf = amp != nil ? [amp getSubmenu: i] : nil;
        check (leaf != nil && [leaf isLeafNode], "leaf node");
        snprintf (what, sizeof what, "Amplitude leaf %d is named %s", i, leafNames[i]);
        check (leaf != nil
                 && [[leaf getNameAsString]
                       isEqualToString: [NSString stringWithUTF8String: leafNames[i]]],
                what);
        snprintf (what, sizeof what, "Amplitude leaf %d targets %s", i, leafTargets[i]);
        check (leaf != nil
                 && [NSStringFromSelector ([leaf getMessage])
                       isEqualToString: [NSString stringWithUTF8String: leafTargets[i]]],
                what);
        check (leaf != nil && [leaf getReceiver] == module,
               "Amplitude leaf targets the module");
        }
    id rev = root != nil ? [root getSubmenu: 1] : nil;
    check (rev != nil && [rev isLeafNode]
             && [[rev getNameAsString] isEqualToString: @"Reverse"],
           "the second child is the Reverse leaf");
    check (rev != nil
             && [NSStringFromSelector ([rev getMessage]) isEqualToString: @"reverseIt:"],
           "Reverse targets reverseIt:");
    check (rev != nil && [rev getReceiver] == module, "Reverse targets the module");

    /* The module's five outlet ivars and the one-byte nib_loaded
       flag: all exist and start un-wired (the gorm wires them when
       the real panel loads - the resoundmenu --perform probe). */
    Ivar mcIvar = class_getInstanceVariable ([module class], "moduleController");
    check (mcIvar != NULL, "moduleController ivar (for the DSP cases)");
    static const char *outletNames[] = {
        "multiplyPanel", "percentChangeScroller", "percentChangeField",
        "shiftPanel", "shiftSliderValue"
    };
    int o;
    for (o = 0; o < 5; o++)
        {
        char what[80];
        snprintf (what, sizeof what, "%s ivar exists", outletNames[o]);
        check (class_getInstanceVariable ([module class], outletNames[o]) != NULL, what);
        snprintf (what, sizeof what, "%s ivar starts nil", outletNames[o]);
        check (readObjIvar (module, outletNames[o]) == nil, what);
        }
    check (readSizedIvar (module, "nib_loaded") == 0, "nib_loaded starts unset");

    /* The two lazy panel loads with the outlets pre-set to fakes
       (a real panel load needs a display - the app-side half is the
       resoundmenu --perform probe, where the gorm panel comes up):
       each then just orders its own panel key and front, the
       one-byte flag stays set. */
    FakeMathPanel *multiplyPanel = [[[FakeMathPanel alloc] init] autorelease];
    FakeMathPanel *shiftPanel = [[[FakeMathPanel alloc] init] autorelease];
    object_setIvar (module, class_getInstanceVariable ([module class],
                                                       "multiplyPanel"), multiplyPanel);
    object_setIvar (module, class_getInstanceVariable ([module class],
                                                       "shiftPanel"), shiftPanel);
    writeSizedIvar (module, "nib_loaded", 1);

    id ret = [(MathModule *)module showMultiplyPanel: nil];
    check (ret == module, "showMultiplyPanel: returns self");
    check ([multiplyPanel keyFrontCount] == 1,
           "showMultiplyPanel: ordered the multiply panel key and front");
    check ([shiftPanel keyFrontCount] == 0,
           "showMultiplyPanel: leaves the shift panel alone");
    check (readSizedIvar (module, "nib_loaded") == 1,
           "nib_loaded stays set (no reload)");
    [(MathModule *)module showMultiplyPanel: nil];
    check ([multiplyPanel keyFrontCount] == 2, "showMultiplyPanel: is repeatable");

    ret = [(MathModule *)module showShiftPanel: nil];
    check (ret == module, "showShiftPanel: returns self");
    check ([shiftPanel keyFrontCount] == 1,
           "showShiftPanel: ordered the shift panel key and front");
    check ([multiplyPanel keyFrontCount] == 2,
           "showShiftPanel: leaves the multiply panel alone");
    [(MathModule *)module showShiftPanel: nil];
    check ([shiftPanel keyFrontCount] == 2, "showShiftPanel: is repeatable");

    /* The two percent presets: the 1998 methods only write the
       field and the scroller (the gorm's Apply button then runs
       multiplyIt:), so the fakes' values are the whole effect. */
    FakeMathField *field = [[[FakeMathField alloc] initWithFloatValue: 100.0f] autorelease];
    FakeMathScroller *scroller =
        [[[FakeMathScroller alloc] initWithFloatValue: 100.0f] autorelease];
    object_setIvar (module, class_getInstanceVariable ([module class],
                                                       "percentChangeField"), field);
    object_setIvar (module, class_getInstanceVariable ([module class],
                                                       "percentChangeScroller"), scroller);
    ret = [(MathModule *)module halve: nil];
    check (ret == module, "halve: returns self");
    check ([field intValue] == 50 && [field floatValue] == 50.0f,
           "halve: set the field to 50");
    check ([scroller intValue] == 50 && [scroller floatValue] == 50.0f,
           "halve: set the scroller to 50");
    ret = [(MathModule *)module double: nil];
    check (ret == module, "double: returns self");
    check ([field intValue] == 200 && [field floatValue] == 200.0f,
           "double: set the field to 200");
    check ([scroller intValue] == 200 && [scroller floatValue] == 200.0f,
           "double: set the scroller to 200");

    /* The DSP matrix: the six actions on real in-memory Snds,
       whole-sound and partial selections, mono and stereo, over
       the five 1998 data formats, through the duck-typed
       controller (the fakes answer the two view methods and record
       the two side effects).  Each case checks the return, the
       stop / soundChanged counts, the preserved shape, and the
       buffer against the mirrored 1998 arithmetic (the full-buffer
       compare also proves the unselected bytes stay untouched). */
    int c;
    int ch;
    for (c = 0; c < 5; c++)
        for (ch = 1; ch <= 2; ch++)
            testMathAbs (module, mcIvar, (SndSampleFormat)dspFormats[c], ch,
                         0, 200);
    /* the selection plumbing: a partial 50-frame window, and the
       1998 zero-length fall-through (the whole sound) */
    testMathAbs (module, mcIvar, SND_FORMAT_LINEAR_16, 1, 10, 50);
    testMathAbs (module, mcIvar, SND_FORMAT_LINEAR_16, 1, 0, 0);

    for (c = 0; c < 5; c++)
        for (ch = 1; ch <= 2; ch++)
            testMathInvert (module, mcIvar, (SndSampleFormat)dspFormats[c], ch,
                            0, 200);

    /* The slider values the 1998 panel offers: 50 (halve), 100
       (the gorm default - exact identity), 200 (double, the clip
       pair earns its keep); the stereo pass at the identity
       covers the interleaved loop. */
    static const float multSliders[] = { 50.0f, 100.0f, 200.0f };
    int s;
    for (c = 0; c < 5; c++)
        for (s = 0; s < 3; s++)
            testMathMultiply (module, mcIvar, (SndSampleFormat)dspFormats[c], 1,
                              0, 200, multSliders[s]);
    for (c = 0; c < 5; c++)
        testMathMultiply (module, mcIvar, (SndSampleFormat)dspFormats[c], 2,
                          0, 200, 100.0f);

    /* The vertical-shift slider: -1 (one clip step down), 0.5,
       1 (one clip step up). */
    static const float shiftSliders[] = { -1.0f, 0.5f, 1.0f };
    for (c = 0; c < 5; c++)
        for (s = 0; s < 3; s++)
            testMathShift (module, mcIvar, (SndSampleFormat)dspFormats[c], 1,
                           0, 200, shiftSliders[s]);
    for (c = 0; c < 5; c++)
        testMathShift (module, mcIvar, (SndSampleFormat)dspFormats[c], 2,
                       0, 200, 0.5f);

    for (c = 0; c < 5; c++)
        for (ch = 1; ch <= 2; ch++)
            testMathMaximize (module, mcIvar, (SndSampleFormat)dspFormats[c], ch,
                              0, 200);
    testMathMaximize (module, mcIvar, SND_FORMAT_LINEAR_16, 1, 10, 50);

    for (c = 0; c < 5; c++)
        for (ch = 1; ch <= 2; ch++)
            testMathReverse (module, mcIvar, (SndSampleFormat)dspFormats[c], ch,
                             0, 200);
    testMathReverse (module, mcIvar, SND_FORMAT_LINEAR_16, 1, 10, 50);
}

/*
The Channel module's per-format transforms, mirrored from the
ported 1998 arms - the same per-format pointer types, the same
loop bounds, the same assignment order, so the expected buffer
is exactly what the 1998-faithful module code computes on the
same input.  swap: is the 1998 byte/sample pair swap of every
format arm (the mu-law arm swaps the mu-law bytes directly, no
decode); stripLeft: / stripRight: copy the odd / even samples of
the selection into the freshly built mono sound, the 1998 loop
bound asymmetry included (x < (first+len)*ch for the left,
x < (first+len)*ch - 1 for the right); addLeft: / addRight:
interleave the selection with a zero (the mu-law arm with
SndKit's SndLinearToMuLaw(0), the 1998 SNDMulaw(0) rename).
*/
static void channelExpectSwap (void *buf, unsigned int first, unsigned int len,
                               int ch, SndSampleFormat fmt)
{
    /* 1998: one function-level `char trader` behind all five arms.
       The wider formats round-trip their values through that single
       byte, so the last written element of the selection comes back
       truncated to it and re-extended to the element width.  The
       module keeps the quirk, and this mirror must reproduce it. */
    char trader;
    switch (fmt)
        {
        case SND_FORMAT_MULAW_8:
            {
            char *d = (char *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                { trader = d[x]; d[x] = d[x + 1]; d[x + 1] = trader; }
            } break;
        case SND_FORMAT_LINEAR_8:
            {
            char *d = (char *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                { trader = d[x]; d[x] = d[x + 1]; d[x + 1] = trader; }
            } break;
        case SND_FORMAT_LINEAR_16:
            {
            signed short *d = (signed short *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                { trader = d[x]; d[x] = d[x + 1]; d[x + 1] = trader; }
            } break;
        case SND_FORMAT_FLOAT:
            {
            float *d = (float *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                { trader = d[x]; d[x] = d[x + 1]; d[x + 1] = trader; }
            } break;
        case SND_FORMAT_DOUBLE:
            {
            double *d = (double *)buf;
            int x;
            for (x = first * ch; x < (first + len) * ch; x++)
                { trader = d[x]; d[x] = d[x + 1]; d[x + 1] = trader; }
            } break;
        default:
            break;
        }
}

/* The 1998 strip pair: keep the even (left) or odd (right)
   samples of the selection in the fresh mono buffer - the rest
   of the (whole-length) new buffer stays the initializer's zero. */
static void channelExpectStrip (void *in, void *out, unsigned int first,
                                unsigned int len, int ch, SndSampleFormat fmt,
                                int keepRight)
{
    switch (fmt)
        {
        case SND_FORMAT_MULAW_8:
            {
            char *d = (char *)in;
            char *nd = (char *)out;
            int y = 0;
            int x;
            if (keepRight)
                for (x = first * ch + 1; x < (first + len) * ch; x += 2)
                    { nd[y++] = d[x]; }
            else
                for (x = first * ch; x < (first + len) * ch - 1; x += 2)
                    { nd[y++] = d[x]; }
            } break;
        case SND_FORMAT_LINEAR_8:
            {
            char *d = (char *)in;
            char *nd = (char *)out;
            int y = 0;
            int x;
            if (keepRight)
                for (x = first * ch + 1; x < (first + len) * ch; x += 2)
                    { nd[y++] = d[x]; }
            else
                for (x = first * ch; x < (first + len) * ch - 1; x += 2)
                    { nd[y++] = d[x]; }
            } break;
        case SND_FORMAT_LINEAR_16:
            {
            signed short *d = (signed short *)in;
            signed short *nd = (signed short *)out;
            int y = 0;
            int x;
            if (keepRight)
                for (x = first * ch + 1; x < (first + len) * ch; x += 2)
                    { nd[y++] = d[x]; }
            else
                for (x = first * ch; x < (first + len) * ch - 1; x += 2)
                    { nd[y++] = d[x]; }
            } break;
        case SND_FORMAT_FLOAT:
            {
            float *d = (float *)in;
            float *nd = (float *)out;
            int y = 0;
            int x;
            if (keepRight)
                for (x = first * ch + 1; x < (first + len) * ch; x += 2)
                    { nd[y++] = d[x]; }
            else
                for (x = first * ch; x < (first + len) * ch - 1; x += 2)
                    { nd[y++] = d[x]; }
            } break;
        case SND_FORMAT_DOUBLE:
            {
            double *d = (double *)in;
            double *nd = (double *)out;
            int y = 0;
            int x;
            if (keepRight)
                for (x = first * ch + 1; x < (first + len) * ch; x += 2)
                    { nd[y++] = d[x]; }
            else
                for (x = first * ch; x < (first + len) * ch - 1; x += 2)
                    { nd[y++] = d[x]; }
            } break;
        default:
            break;
        }
}

/* The 1998 add pair: interleave the selection with a blank
   channel - the linear arms zero the new channel, the mu-law
   arm the mu-law code of zero (the 1998 "it's probably 127"
   note included, through SndKit's SndLinearToMuLaw) - into the
   freshly built stereo buffer; the frames past the selection
   stay the initializer's zero. */
static void channelExpectAdd (void *in, void *out, unsigned int first,
                              unsigned int len, int ch, SndSampleFormat fmt,
                              int blankLeft)
{
    switch (fmt)
        {
        case SND_FORMAT_MULAW_8:
            {
            char *d = (char *)in;
            char *nd = (char *)out;
            int y = 0;
            int x;
            if (blankLeft)
                for (x = first * ch; x < (first + len) * ch; x++)
                    { nd[y] = SndLinearToMuLaw (0); nd[y + 1] = d[x]; y += 2; }
            else
                for (x = first * ch; x < (first + len) * ch; x++)
                    { nd[y + 1] = SndLinearToMuLaw (0); nd[y] = d[x]; y += 2; }
            } break;
        case SND_FORMAT_LINEAR_8:
            {
            char *d = (char *)in;
            char *nd = (char *)out;
            int y = 0;
            int x;
            if (blankLeft)
                for (x = first * ch; x < (first + len) * ch; x++)
                    { nd[y] = 0; nd[y + 1] = d[x]; y += 2; }
            else
                for (x = first * ch; x < (first + len) * ch; x++)
                    { nd[y + 1] = 0; nd[y] = d[x]; y += 2; }
            } break;
        case SND_FORMAT_LINEAR_16:
            {
            signed short *d = (signed short *)in;
            signed short *nd = (signed short *)out;
            int y = 0;
            int x;
            if (blankLeft)
                for (x = first * ch; x < (first + len) * ch; x++)
                    { nd[y] = 0; nd[y + 1] = d[x]; y += 2; }
            else
                for (x = first * ch; x < (first + len) * ch; x++)
                    { nd[y + 1] = 0; nd[y] = d[x]; y += 2; }
            } break;
        case SND_FORMAT_FLOAT:
            {
            float *d = (float *)in;
            float *nd = (float *)out;
            int y = 0;
            int x;
            if (blankLeft)
                for (x = first * ch; x < (first + len) * ch; x++)
                    { nd[y] = 0; nd[y + 1] = d[x]; y += 2; }
            else
                for (x = first * ch; x < (first + len) * ch; x++)
                    { nd[y + 1] = 0; nd[y] = d[x]; y += 2; }
            } break;
        case SND_FORMAT_DOUBLE:
            {
            double *d = (double *)in;
            double *nd = (double *)out;
            int y = 0;
            int x;
            if (blankLeft)
                for (x = first * ch; x < (first + len) * ch; x++)
                    { nd[y] = 0; nd[y + 1] = d[x]; y += 2; }
            else
                for (x = first * ch; x < (first + len) * ch; x++)
                    { nd[y + 1] = 0; nd[y] = d[x]; y += 2; }
            } break;
        default:
            break;
        }
}

static void testChannelSwap (id module, Ivar mcIvar, SndSampleFormat fmt,
                             unsigned int first, unsigned int len)
{
    const char *name = [SndFormatName (fmt, NO) cStringUsingEncoding: NSASCIIStringEncoding];
    printf ("== channel: swap: %s, 2 channels, selection (%u,%u)\n",
            name, first, len);

    Snd *snd = [[[Snd alloc] initWithFormat: fmt
                                channelCount: 2
                                    frames: 200
                              samplingRate: 44100.0f] autorelease];
    check (snd != nil && [snd lengthInSampleFrames] == 200, "in-memory Snd");
    fillPattern (snd, 0);
    long size = [snd dataSize];
    unsigned char *before = malloc ((size_t)size);
    memcpy (before, [snd bytes], (size_t)size);

    FakeChannelView *view = [[[FakeChannelView alloc] initWithSound: snd] autorelease];
    [view setSelection: first size: len];
    FakeChannelController *mc =
        [[[FakeChannelController alloc] initWithSound: snd soundView: view] autorelease];
    object_setIvar (module, mcIvar, mc);

    /* The 1998 fall-through: a zero-length selection becomes the
       whole sound. */
    unsigned int effFirst = first, effLen = len;
    if (effLen == 0)
        {
        effFirst = 0;
        effLen = 200;
        }

    id ret = [(ChannelModule *)module swap: nil];
    
    check (ret == module, "swap: returns self");
    check ([mc stopCount] == 1, "swap: stopped the playback");
    check ([mc soundChangedCount] == 1, "swap: reported the sound changed");
    check ([mc newSoundCount] == 0, "swap: built no new sound");
    check ([snd dataFormat] == fmt && [snd channelCount] == 2
       && [snd lengthInSampleFrames] == 200,
            "the sound keeps its format, channels and length");

    unsigned char *expected = malloc ((size_t)size);
    memcpy (expected, before, (size_t)size);
    channelExpectSwap (expected, effFirst, effLen, 2, fmt);

    /* The 1998 loop shifts the selection one element left; the last
       written element comes back through the char trader, which the
       mirror reproduces.  For a whole selection the loop additionally
       reads one element past the buffer end, so the last in-range
       element holds whatever the heap kept there - different between
       the Snd buffer and this malloc'd mirror - and is excluded. */
    long cmpSize = size;
    if (effFirst + effLen == 200)
        cmpSize = size - size / (200 * 2);
    check (memcmp ([snd bytes], expected, (size_t)cmpSize) == 0,
            "the buffer matches the 1998 swap loop");
    free (before);
    free (expected);
}

static void testChannelStrip (id module, Ivar mcIvar, SndSampleFormat fmt,
                              unsigned int first, unsigned int len, int keepRight)
{
    const char *name = [SndFormatName (fmt, NO) cStringUsingEncoding: NSASCIIStringEncoding];
    printf ("== channel: %s %s, 2 channels, selection (%u,%u)\n",
            keepRight ? "stripLeft:" : "stripRight:", name, first, len);

    Snd *snd = [[[Snd alloc] initWithFormat: fmt
                                channelCount: 2
                                    frames: 200
                              samplingRate: 44100.0f] autorelease];
    check (snd != nil && [snd lengthInSampleFrames] == 200, "in-memory Snd");
    fillPattern (snd, 0);
    long size = [snd dataSize];
    unsigned char *before = malloc ((size_t)size);
    memcpy (before, [snd bytes], (size_t)size);

    FakeChannelView *view = [[[FakeChannelView alloc] initWithSound: snd] autorelease];
    [view setSelection: first size: len];
    FakeChannelController *mc =
        [[[FakeChannelController alloc] initWithSound: snd soundView: view] autorelease];
    object_setIvar (module, mcIvar, mc);

    unsigned int effFirst = first, effLen = len;
    if (effLen == 0)
        {
        effFirst = 0;
        effLen = 200;
        }

    id ret = keepRight ? [(ChannelModule *)module stripLeft: nil]
                       : [(ChannelModule *)module stripRight: nil];

    check (ret == module, "the strip returns self");
    check ([mc stopCount] == 1, "the strip stopped the playback");
    check ([mc soundChangedCount] == 0, "the strip leaves the old sound alone");
    check ([mc newSoundCount] == 1, "the strip handed off the fresh sound");
    Snd *fresh = [mc currentSound];
    check ([[mc currentSound] isEqual: [view sound]],
           "the view and the controller hold the same fresh sound");
    check (fresh != nil && [fresh dataFormat] == fmt
       && [fresh channelCount] == 1 && [fresh lengthInSampleFrames] == 200,
            "the fresh sound is mono, whole-length, same format");

    long freshSize = [fresh dataSize];
    check (freshSize == size / 2,
           "the fresh sound is sized for half the data");
    unsigned char *expected = malloc ((size_t)freshSize);
    memset (expected, 0, (size_t)freshSize);
    channelExpectStrip (before, expected, effFirst, effLen, 2, fmt, keepRight);
    check (memcmp ([fresh bytes], expected, (size_t)freshSize) == 0,
            "the fresh buffer matches the 1998 strip arithmetic");
    check (memcmp ([snd bytes], before, (size_t)size) == 0,
            "the original sound is untouched");
    free (before);
    free (expected);
}

static void testChannelAdd (id module, Ivar mcIvar, SndSampleFormat fmt,
                            unsigned int first, unsigned int len, int blankLeft)
{
    const char *name = [SndFormatName (fmt, NO) cStringUsingEncoding: NSASCIIStringEncoding];
    printf ("== channel: %s %s, 1 channel, selection (%u,%u)\n",
            blankLeft ? "addLeft:" : "addRight:", name, first, len);

    Snd *snd = [[[Snd alloc] initWithFormat: fmt
                                channelCount: 1
                                    frames: 200
                              samplingRate: 44100.0f] autorelease];
    check (snd != nil && [snd lengthInSampleFrames] == 200, "in-memory Snd");
    fillPattern (snd, 0);
    long size = [snd dataSize];
    unsigned char *before = malloc ((size_t)size);
    memcpy (before, [snd bytes], (size_t)size);

    FakeChannelView *view = [[[FakeChannelView alloc] initWithSound: snd] autorelease];
    [view setSelection: first size: len];
    FakeChannelController *mc =
        [[[FakeChannelController alloc] initWithSound: snd soundView: view] autorelease];
    object_setIvar (module, mcIvar, mc);

    unsigned int effFirst = first, effLen = len;
    if (effLen == 0)
        {
        effFirst = 0;
        effLen = 200;
        }

    id ret = blankLeft ? [(ChannelModule *)module addLeft: nil]
                       : [(ChannelModule *)module addRight: nil];

    check (ret == module, "the add returns self");
    check ([mc stopCount] == 1, "the add stopped the playback");
    check ([mc soundChangedCount] == 0, "the add leaves the old sound alone");
    check ([mc newSoundCount] == 1, "the add handed off the fresh sound");
    Snd *fresh = [mc currentSound];
    check ([[mc currentSound] isEqual: [view sound]],
           "the view and the controller hold the same fresh sound");
    check (fresh != nil && [fresh dataFormat] == fmt
       && [fresh channelCount] == 2 && [fresh lengthInSampleFrames] == 200,
            "the fresh sound is stereo, whole-length, same format");

    long freshSize = [fresh dataSize];
    check (freshSize == size * 2,
           "the fresh sound is sized for twice the data");
    unsigned char *expected = malloc ((size_t)freshSize);
    memset (expected, 0, (size_t)freshSize);
    channelExpectAdd (before, expected, effFirst, effLen, 1, fmt, blankLeft);
    check (memcmp ([fresh bytes], expected, (size_t)freshSize) == 0,
            "the fresh buffer matches the 1998 add arithmetic");
    check (memcmp ([snd bytes], before, (size_t)size) == 0,
            "the original sound is untouched");
    free (before);
    free (expected);
}

static void runChannel (Class principal)
{
    /* The menu tree the app's Modules menu is built from: the 1998
       init builds a "Channel" submenu - the add/strip/swap leaves
       in the 1998 addSubmenu order (addLeft, addRight, stripLeft,
       stripRight, swap), every target the module itself. */
    id module = [[principal alloc] init];
    check (module != nil, "module instantiation");
    id root = [module getModuleMenuNode];
    check (root != nil, "root menu node");
    check (root != nil && [root numSubmenus] == 1,
           "root has exactly one child");
    id chan = root != nil ? [root getSubmenu: 0] : nil;
    check (chan != nil && ![chan isLeafNode]
             && [[chan getNameAsString] isEqualToString: @"Channel"],
           "the child is the Channel submenu");
    check (chan != nil && [chan numSubmenus] == 5,
           "Channel holds exactly five leaves");
    static const char *leafNames[] = {
        "Add a Blank Left Channel", "Add a Blank Right Channel",
        "Delete the Left Channel", "Delete the Right Channel",
        "Swap Channels"
    };
    static const char *leafTargets[] = {
        "addLeft:", "addRight:", "stripLeft:", "stripRight:", "swap:"
    };
    int i;
    for (i = 0; i < 5; i++)
        {
        char what[80];
        id leaf = chan != nil ? [chan getSubmenu: i] : nil;
        check (leaf != nil && [leaf isLeafNode], "leaf node");
        snprintf (what, sizeof what, "Channel leaf %d is named %s", i, leafNames[i]);
        check (leaf != nil
                 && [[leaf getNameAsString]
                       isEqualToString: [NSString stringWithUTF8String: leafNames[i]]],
                what);
        snprintf (what, sizeof what, "Channel leaf %d targets %s", i, leafTargets[i]);
        check (leaf != nil
                 && [NSStringFromSelector ([leaf getMessage])
                       isEqualToString: [NSString stringWithUTF8String: leafTargets[i]]],
                what);
        check (leaf != nil && [leaf getReceiver] == module,
               "Channel leaf targets the module");
        }

    /* The module has no outlets at all (the 1998 ivar block is
       empty) - the family's second panel-less module after Zero -
       so the contract is the menu tree and the DSP matrix only. */

    Ivar mcIvar = class_getInstanceVariable ([module class], "moduleController");
    check (mcIvar != NULL, "moduleController ivar (for the DSP cases)");

    /* The DSP matrix: the five actions on real in-memory Snds,
       whole-sound and partial selections, over the five 1998 data
       formats, through the duck-typed controller.  swap: and the
       strip pair need stereo (the 1998 channel-count guard), the
       add pair mono; each case checks the return, the side
       effects, the preserved / fresh shape, and the buffer against
       the mirrored 1998 arithmetic (the full-buffer compare also
       proves the untouched bytes). */
    int c;
    for (c = 0; c < 5; c++)
        {
        testChannelSwap (module, mcIvar, (SndSampleFormat)dspFormats[c], 0, 200);
        testChannelSwap (module, mcIvar, (SndSampleFormat)dspFormats[c], 10, 50);
        }
    /* the 1998 zero-length fall-through, on one format */
    testChannelSwap (module, mcIvar, SND_FORMAT_LINEAR_16, 0, 0);

    for (c = 0; c < 5; c++)
        {
        testChannelStrip (module, mcIvar, (SndSampleFormat)dspFormats[c], 0, 200, YES);
        testChannelStrip (module, mcIvar, (SndSampleFormat)dspFormats[c], 0, 200, NO);
        testChannelStrip (module, mcIvar, (SndSampleFormat)dspFormats[c], 10, 50, YES);
        testChannelStrip (module, mcIvar, (SndSampleFormat)dspFormats[c], 10, 50, NO);
        }
    testChannelStrip (module, mcIvar, SND_FORMAT_LINEAR_16, 0, 0, YES);
    testChannelStrip (module, mcIvar, SND_FORMAT_LINEAR_16, 0, 0, NO);

    for (c = 0; c < 5; c++)
        {
        testChannelAdd (module, mcIvar, (SndSampleFormat)dspFormats[c], 0, 200, YES);
        testChannelAdd (module, mcIvar, (SndSampleFormat)dspFormats[c], 0, 200, NO);
        testChannelAdd (module, mcIvar, (SndSampleFormat)dspFormats[c], 10, 50, YES);
        testChannelAdd (module, mcIvar, (SndSampleFormat)dspFormats[c], 10, 50, NO);
        }
    testChannelAdd (module, mcIvar, SND_FORMAT_LINEAR_16, 0, 0, YES);
    testChannelAdd (module, mcIvar, SND_FORMAT_LINEAR_16, 0, 0, NO);
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
    else if ([NSStringFromClass (principal) isEqualToString: @"EnvelopeModule"])
        runEnvelope (principal);
    else if ([NSStringFromClass (principal) isEqualToString: @"EchoChamber"])
        runEcho (principal);
    else if ([NSStringFromClass (principal) isEqualToString: @"GateModule"])
        runGate (principal);
    else if ([NSStringFromClass (principal) isEqualToString: @"FilterModule"])
        runFilter (principal);
    else if ([NSStringFromClass (principal) isEqualToString: @"WaveBuilderModule"])
        runWaveBuilder (principal);
    else if ([NSStringFromClass (principal) isEqualToString: @"FFTModule"])
        runFFT (principal);
    else if ([NSStringFromClass (principal) isEqualToString: @"MathModule"])
        runMath (principal);
    else if ([NSStringFromClass (principal) isEqualToString: @"ChannelModule"])
        runChannel (principal);
    else
        check (NO, "principal class is none of the ported module classes");

    if (failures == 0)
        printf ("resoundmodule: all checks passed\n");
    else
        printf ("resoundmodule: %d check(s) failed\n", failures);
    return failures == 0 ? 0 : 1;
}
