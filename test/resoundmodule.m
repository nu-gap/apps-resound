/*
resoundmodule
For the GNUstep port of Resound (gnustep-port branch)

The Phase 3 load contracts for the ported modules - so far the Zero
module (zeroSound:), the Mix module (mix:), the Envelope module
(applyEnvelope:), the EchoChamber module (begin:/performEcho:) and
the Gate module (showNoiseGatePanel:/gateIt:) - the first five units
from the module tree (see docs/GNUSTEP_BUILD.md).

What it does (headless: no display, no audio device):

  1. Loads the built module bundle through NSBundle and checks the
     principal class.  The app's ModuleController loadAModule: does
     exactly this - the bundle's generated Info-gnustep.plist carries
     NSPrincipalClass, and the principal class is the class the app
     instantiates - so the test dispatches on the class name, exactly
     like the app: ZeroModule runs the zero contract, MixModule the
     mix contract, EnvelopeModule the envelope contract,
     EchoChamber the echo contract, GateModule the gate contract.

  2. Instantiates the module (the same alloc/init the app runs) and
     checks the menu tree the 1998 init builds: exactly one leaf -
     named "Zero" targeting zeroSound:, or "Mix In" targeting mix:,
     or "Envelope" targeting showEnvelopePanel:, or "Echo
     Chamber..." targeting begin:, or "Noise Gate..." targeting
     showNoiseGatePanel:,
     on the module itself - what the app's "Modules" menu shows
     after the load.  The gorm-wired modules additionally expose
     their private ivars here (the Envelope panel outlets, the
     EchoChamber value outlets and windowLoaded flag, the Gate
     panel outlets and nib_loaded flag), all checked to exist and
     to start in the un-wired state.

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
           --perform probe).

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
So are the EchoChamber's five value outlets and the Gate panel's
three value outlets and panel window.  The Gate's nib_loaded flag
is a one-byte BOOL - the 1998 header declares it ahead of the four
outlet pointers - so a pointer-sized object_setIvar on it would
write into the outlets' bytes; the gate contract reads and writes
it through the type-encoding-aware sized ivar helpers instead.

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
#import <stdlib.h>

/* The app's copy of the module base classes, the same files the tool
   compiles in below (../Source/Module.m) - one path for the shared
   headers, so #import dedupes them. */
#import "../Source/Module.h"

/* Minimal local mirrors of the three module headers, instead of the
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
    else
        check (NO, "principal class is none of the ported module classes");

    if (failures == 0)
        printf ("resoundmodule: all checks passed\n");
    else
        printf ("resoundmodule: %d check(s) failed\n", failures);
    return failures == 0 ? 0 : 1;
}
