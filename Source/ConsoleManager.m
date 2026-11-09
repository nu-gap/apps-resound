/* DONE */

/*
Copyright (c) 1998 by Sean Luke (hereafter referred to as "the Author")
seanl@cs.umd.edu     http://www.cs.umd.edu/users/seanl/

Permission to use, copy, modify, and distribute the source code and
related materials of this software for any purpose and without fee is
hereby granted, provided the Author's name shall not be used in
advertising or publicity pertaining to this material without the
specific, prior written permission of the Author, acknowledgement
of the author appears prominently in the distributed documentation
of any software application derived from this source code, and this
copyright notice appears in all derived source copies.  SEAN LUKE MAKES
NO REPRESENTATIONS ABOUT THE ACCURACY OR SUITABILITY OF THIS MATERIAL
FOR ANY PURPOSE.  IT IS PROVIDED "AS IS", WITHOUT ANY EXPRESS OR
IMPLIED WARRANTIES.

*/
/****************************************************************************

  ConsoleManager.[h|m]
  Sean Luke
  
  The Console Manager is the controller object responsible for handling the
  Console Window, the Record and Play panels, and the auto-scroll and play mark
  on Resound's SoundViews.  The ConsoleManager works closely with the SoundController,
  which is the object responsible for actually managing recording and playing of
  sounds.  Realistically, these two objects could be merged at a later date, but
  intertia prevents me from doing so.  :-)
  
  ****************************************************************************/





#import "ConsoleManager.h"
#import "FileController.h"
#import "ResoundNibs.h"
#import "SoundManager.h"
#import "ResoundMiscVolumeMeter.h"
#import "MiscSoundTracker.h"
#import "ResoundMiscSoundView.h"
#import <AppKit/AppKit.h>
#import <SndKit/SndKit.h>
#import <stdio.h>

#ifndef __BUILDING_RHAPSODY
#import "MiscVolumeLight.h"
//#import "MiscAppIcon.h"
#endif

#define SOURCE_MIC @"Mic"
#define SOURCE_LINE @"Line"
#define LENGTH_5_MINUTES @"300"        /* String Macro Value -- can't have ints in strings */
#define F_LENGTH_5_MINUTES 300.0      /* Integer Macro Value */

// SndKit has no per-device encoding list (the legacy asked the NXSoundIn
// for it); the record panel offers the three encodings SoundKit can
// capture in.  (A-Law and AES were never usable in the 1998 file either
// -- they carried usable=0.)
static SndSampleFormat CONSOLE_FORMATS[3]=
    {SND_FORMAT_LINEAR_16, SND_FORMAT_LINEAR_8, SND_FORMAT_MULAW_8};
#define CONSOLE_FORMAT_COUNT \
    ((int)(sizeof(CONSOLE_FORMATS)/sizeof(CONSOLE_FORMATS[0])))

@implementation ConsoleManager


/**** registerDefaults:::::
  Initializes defaults for console manager.
*/


- registerDefaults
{
    NSString* channel;
    NSString* rate;
    NSString* encoding;

    NSDictionary* dict;
    /*float *s_rates;
    unsigned int n_rates;*/

    if (input_format.channelCount>0)
        channel = ((input_format.channelCount==1) ? @"1" : @"2");
    else channel = @"-1";

	{
	double defaultrate = 22050;
	double lowrate= 500;
	double hirate = 1000000;
	double r = input_format.sampleRate;
	rate = [NSString stringWithFormat:@"%f", (r > lowrate && r < hirate ?
		r : defaultrate)];
	}


    // SndKit has no per-device encoding list (the legacy asked the
    // NXSoundIn for it); the record panel offers the three encodings
    // SoundKit can capture in, so the default is the first of them.
    encoding=@"0";

    dict=
        [NSDictionary dictionaryWithObjectsAndKeys:
            channel, @"RecordChannels",
            rate, @"RecordRate",
            encoding, @"RecordEncoding",
            SOURCE_MIC, @"RecordSource",
            LENGTH_5_MINUTES, @"RecordLength",
            nil];

    [[NSUserDefaults standardUserDefaults] registerDefaults:
        dict];
    return self;
    }







/**** init
  Initializes Console Manager 
*/

- init
    {
    id returnval=[super init];
    int x;

    NSString* defaultChannel;
    NSString* defaultRate;
    NSString* defaultEncoding;
    NSString* defaultSource;
    NSString* defaultLength;
    
    input_format = [Snd nativeInputFormat];
    [ResoundNibs loadNibNamed: @"Console" owner:self];
    
    // Register Defaults
    
    [self registerDefaults];

    {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        defaultChannel = [defaults stringForKey: @"RecordChannels"];
        defaultRate = [defaults stringForKey: @"RecordRate"];
        defaultEncoding = [defaults stringForKey: @"RecordEncoding"];
        defaultSource = [defaults stringForKey: @"RecordSource"];
        defaultLength = [defaults stringForKey: @"RecordLength"];
    }

    
#ifndef __BUILDING_RHAPSODY
    // Set up hidden window
    
	{
	NSPoint	contentViewOrigin = { 8.0, 8.0 };
	[NSApp cleanTileToWindow: hidden_window];
	[[hidden_window contentView] lockFocus];
	[[NXImage findImageNamed: @"FourSounds"] composite:NX_SOVER toPoint:&contentViewOrigin];
	[[hidden_window contentView] unlockFocus];
	}
#endif

    // start trackers
    
    [soundTracker setRefresh:.05];
    [soundTracker sendSeconds];
    [soundTracker setDefaultSamplingRate:SND_RATE_CODEC];
    [meter setDelegate:self];
    [meter setRefresh:.05];
#ifndef __BUILDING_RHAPSODY
    [Light setDelegate:self];
    [Light setBezeled:NO];
    [Light setRefresh:.05];
#endif
    
    // Set the Input Gains...
    // SndKit has no input gain device parameters (the legacy read
    // NX_SoundDeviceInputGain* on the NXSoundIn); the record gain
    // sliders keep their nib values and are display-only.

    // Set the Input Source...
    // SndKit has no analog input source selector (the legacy set
    // NX_SoundDeviceAnalogInputSource on a throwaway NXSoundIn, which
    // has no counterpart); there is no device-level source switch.
    

    // Here we figure out what rates and formats are available...
    
    [recordLengthField setStringValue:defaultLength];
    
    if (input_format.channelCount==1)
	// Warning, bug in NeXT's docs the name is totally wrong...
	{
	[[channels cellAtRow:1 column:0] setEnabled:NO];
    defaultChannel=@"1";
	}
    else
	{		// which to set?
	int c=[defaultChannel intValue];
	switch (c)
	    {
	  case 2:  defaultChannel=@"2"; break;
      default: defaultChannel=@"1"; break;
		   }		// maybe more later...
	}

    // Set the available rates...

    // SndKit has no per-device sampling rate list (the legacy asked the
    // NXSoundIn for it).  SoundManager resamples the capture to the
    // requested rate in _finishRecording, so the rate menu is always
    // user-defined; the native input rate seeds the field and labels.
    {
    NSString* t;
    [rateMenu setEnabled:NO];
    [rateField setEnabled:YES];
    [rateMenu addItemWithTitle: @"User-Defined:"];
    [rateMenu selectItemWithTitle: @"User-Defined:"];
    [[rateMenu menu] removeItem:[[rateMenu menu] itemWithTitle: @"Default"]];
    // Work-around for a little sprintf bug...
    if ((int)input_format.sampleRate==input_format.sampleRate)	// it's a round number
        t=[NSString stringWithFormat:@"%d",(int)input_format.sampleRate];
    else
        t=[NSString stringWithFormat:@"%f",input_format.sampleRate];
    [minrate setStringValue:t];
    [maxrate setStringValue:t];
    if ([defaultRate floatValue]>0)
        [rateField setFloatValue:[defaultRate floatValue]];
    else
    {
    [rateField setFloatValue:input_format.sampleRate];
    defaultRate=[NSString stringWithFormat:@"%f",input_format.sampleRate];
    }
    }

    // set the available encodings...
    // SndKit has no per-device encoding list (the legacy asked the
    // NXSoundIn for it); the record panel offers the three encodings
    // SoundKit can capture in (A-Law and AES were never usable in the
    // 1998 file either -- they carried usable=0).
    {
    int s=0;		// unset
    int sx=0;
    NSString* t;
    [formatMenu setEnabled:YES];
    for (x=0;x<CONSOLE_FORMAT_COUNT;x++)
        {
        switch (CONSOLE_FORMATS[x])
        {
          case SND_FORMAT_LINEAR_16:
              t=@"16-Bit Linear"; break;
          case SND_FORMAT_LINEAR_8:
              t=@"8-Bit Linear";  break;
          case SND_FORMAT_MULAW_8:
              t=@"8-Bit Mu-Law"; break;
          default:
              t=@"Unknown"; break;
        }
        [[[formatMenu menu] addItemWithTitle:t
                        action:@selector(setFormatToMe:)
                 keyEquivalent:@""] setTarget:self];
        if (x==0) [formatMenu selectItemWithTitle:t];
        if (x==[defaultEncoding intValue])
        {
            [formatMenu selectItemWithTitle:t];
        s=1; sx=x;
        }
    }
    if (!s) defaultEncoding=[NSString stringWithFormat:@"%d",sx];
    [[formatMenu menu] removeItem:[[formatMenu menu] itemWithTitle: @"Default"]];
    }

    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: defaultChannel forKey: @"RecordChannels"];
    [defaults setObject: defaultRate forKey: @"RecordRate"];
    [defaults setObject: defaultEncoding forKey: @"RecordEncoding"];
    [defaults setObject: defaultSource forKey: @"RecordSource"];
    [defaults setObject: defaultLength forKey: @"RecordLength"];
    }
    return returnval;
    }




/**** setDefaultChannelCount:
  Sets the Volume Meter's default channel count.
*/


- setDefaultChannelCount:(int) chan
    {
    return [meter setDefaultChannelCount:chan];
    }


/**** dealloc
  Frees the Console Manager and cleans up.
 */

- (void)dealloc
    {
    [(MiscSoundTracker*)soundTracker stop];
    [super dealloc];
    }



/**** PrepareConsole
  Set up the console at program-initialization time.  Called from FileController.
  */

- prepareConsole
    {
    [console makeKeyAndOrderFront:self];
    return self;
    }


/**** ShowConsole:
  Display the console.  Called by a menu item.
 */

- showConsole:sender;
    {
    [console makeKeyAndOrderFront:sender];
    return self;
    }


/**** SetMeterTo:
  Lock the meter, volume light, and trackers onto a particular sound/soundview for
  recording or playing.  This method does not start them running--see StartMeter.
 */

- setMeterTo: thisSound
    {
    [(MiscVolumeMeter*)meter setSound: thisSound];
#ifndef __BUILDING_RHAPSODY
    [light setSound: thisSound];
#endif
    [(MiscSoundTracker*)soundTracker setSound:thisSound];
    return self;
    }


/**** StopMeter
  Stop the meter, volume light, and trackers.  Unlock them from any sound/soundview.
  */

- stopMeter
    {
    [(ResoundMiscVolumeMeter*)meter stop];
#ifndef __BUILDING_RHAPSODY
    [(MiscVolumeLight*)light stop];
#endif
    // First a little spoofing to make certain that play mark is removed...
    [self clearPlayMark];
    [(MiscVolumeMeter*)meter setSound:nil];	// so VolumeMeter isn't using sound
    // in case sound is freed later
#ifndef __BUILDING_RHAPSODY
    [light setSound:nil];
#endif
    [(MiscSoundTracker*)soundTracker stop];
    [soundTracker clearTarget];
    return self;
    }



/**** StartMeter
  Start the meter, volume light, and trackers running.
*/

- startMeter
    {
    [meter run];
#ifndef __BUILDING_RHAPSODY
    [light run];
#endif
    [soundTracker run];	
    return self;
    }




/*** PlayDown:
  Do what's needed to do when the Play Button has been pressed.
*/

- playDown:sender
    {
    if ([fileController currentSound:self]!=nil)
	{	
	if ([(SoundManager*)soundManager play:self]!=nil) return self;	
	}
    
    // else...
    [playButton setState:(![playButton state])];
    return self;
    }




/**** RecordDown:
  Do what's needed to do when the Record Button has been pressed.
  */

- recordDown:sender
    {

    NSString* defaultChannel;
    NSString* defaultRate;
    NSString* defaultEncoding;
    NSString* defaultLength;
    int c,e;
    float r,l;

    {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        defaultChannel = [defaults stringForKey: @"RecordChannels"];
        defaultRate = [defaults stringForKey: @"RecordRate"];
        defaultEncoding = [defaults stringForKey: @"RecordEncoding"];
        defaultLength = [defaults stringForKey: @"RecordLength"];
    }
    

    c=[defaultChannel intValue]; if (c<=0) c=1; if (c>2) c=2;
    r=[defaultRate intValue]; if (r<=0) r=1;

    // SndKit has no per-device sampling rate list, so the stored rate
    // is passed through as-is: SoundManager resamples the capture to
    // it in _finishRecording.
    
    e=[defaultEncoding intValue];
    if (e>=0&&e<CONSOLE_FORMAT_COUNT) e=CONSOLE_FORMATS[e];
    else e=SND_FORMAT_MULAW_8;
    
    // SndKit has no analog input source selector (see init); there is
    // no device-level source switch to program before recording.
    
    l=[defaultLength intValue];
    if (l<=0.0) l=F_LENGTH_5_MINUTES;
    
    // The format already arrives as an SND_FORMAT_* value (the record
    // panel's encoding menu is built from CONSOLE_FORMATS), so the 1998
    // NX_SoundStreamDataEncoding_*-to-SND_FORMAT_* conversion is gone.

    [soundTracker setDefaultSamplingRate:r];
    
    if ([soundManager record: r: c:  (int) ((e==SND_FORMAT_LINEAR_16 ? 2 : 1)*r*l*c):  e : self] )
    	{
    	[recordButton setState:1];
	//return self;
    	}
    // else
    else
    	[recordButton setState:0];
    //[recordButton setState:(![recordButton state])];
    return self;
    }




/**** PauseDown:
  Do what's needed to do when the pause button has been pressed.
  This could be improved by storing the current number of samples played, as the Sound
  mechanism doesn't keep track of this and therefore the play mark gets reset every time
  you press pause and then unpause again.  Bummer.
*/

- pauseDown:sender
    {	
    if (![soundManager togglePaused:self])
	{
	[pauseButton setState:(![pauseButton state])];
	}
    return self;
    }




/**** StopDown:
  Do what's needed to do when the stop button has been pressed.  Basically, reset stuff.
 */

- stopDown:sender
    {
    [(SoundManager*)soundManager stop:self];
    [recordButton setState:0];
    [playButton setState:0];
    [stopButton setState:0];
    [pauseButton setState:0];
    return self;
    }



/**** meterDidUpdate:
  Delegate method.  If the sender is the VolumeLight in the app icon, then we need to
  set up the icon correctly.  Otherwise we don't do anything.
*/

- meterDidUpdate:sender
    {
#ifndef __BUILDING_RHAPSODY
    if (sender==Light)
	{
	return [NSApp windowToAppIcon:hidden_window];	
	// A MiscAppIcon category method
	}
    else 
#endif
        return self;
    }




/**** metterWillUpdateOnOwn:sender
  Delegate method.  If the sender is the VolumeLight, we need to load it into the app icon.
  otherwise, we need to do the auto-scrolling and play mark functions in the SoundView, which
  are tied to the Meter.
*/

- meterWillUpdateOnOwn:sender
    {
#ifndef __BUILDING_RHAPSODY
    if (sender==Light)
	{
	NSPoint	contentViewOrigin = { 8.0, 8.0 };
	[NSApp cleanTileToWindow: hidden_window];
	[[hidden_window contentView] lockFocus];
	[[NXImage findImageNamed: @"FourSounds"] composite:NX_SOVER toPoint:&contentViewOrigin];
	[[hidden_window contentView] unlockFocus];
	return self;
	}
    else
	{
#endif

    	id snd=[(MiscVolumeMeter*)sender sound];		// note that the meter is tracking the scratch sound,
	// not the real sound!
	id cv=[soundManager soundViewPlayingOrRecording];
	int samp=0;
	int fs,ns;
	BOOL ruler_drawn;
	BOOL need_to_scroll;
	
	if (snd==nil) return self;
	if (cv==nil) return self;

	// First we check to see if the SoundView's even bothering with
	// displaying the ruler or scroll...
	
	ruler_drawn=[cv xAxisDisplayed];
	need_to_scroll=[cv scrollToReflectPlaying];
	if (!ruler_drawn&&!need_to_scroll) return self;
	
	// Now we know we have to draw or scroll...

	// we're assuming here that [sender sound] really _is_ a sound,
	// not a soundview.
	// SndKit has no Sound-style status: the legacy Playing/
	// PlayingPending/PlayingPaused group maps to "a performance is
	// playing (pending counts) or paused".
	if (![snd isKindOfClass:[Snd class]]) return self;
	{
	NSArray* performances=[(Snd*)snd performances];
	int i;
	if (![(Snd*)snd isPlaying])
		{
		for (i=0;i<[performances count];i++)
			if ([[performances objectAtIndex:i] isPaused]) break;
		if (i>=[performances count]) return self;
		}
	}
	

	SndPerformance* performance=[[(Snd*)snd performances] lastObject];
	if (performance) samp=[(Snd*)snd samplesPerformedOfPerformance:performance];
	[cv getSelection:&fs size:&ns];
	if (ns) samp+=fs;			// this is because the samples processed are
	// how _many_ samples have been processed, NOT
	// the sample numbers in the soundview! 
	
	// disable window flush, display, then reenable flush
	
	[[cv window] disableFlushWindow]; 
	if (need_to_scroll) [cv scrollToSample:samp];
	if (ruler_drawn) [cv setPlayMark:samp];
	[[cv window] enableFlushWindow]; 
	[[cv window] flushWindowIfNeeded];
	
	return self;
#ifndef __BUILDING_RHAPSODY
	}
#endif
    }





/**** clearPlayMark
  Clears the play mark.  Performed at end of playing.
*/

- clearPlayMark
    {
    id cv=[soundManager soundViewPlayingOrRecording];
    
    if (cv==nil) return self;

    // disable window flush, display, then reenable flush
    
    [[cv window] disableFlushWindow]; 
    [cv setPlayMark:-1];
    [[cv window] enableFlushWindow]; 
    [[cv window] flushWindowIfNeeded];
    
    return self;
    }



/**** displayRecordFormatPanel:
  Display the record format panel. Called from a menu item.
*/

- displayRecordFormatPanel:sender
    {
    [formatWindow makeKeyAndOrderFront:sender];
    return self;
    }




/**** setRateToMe:
  Sets the default recording rate.  This can be set by either a text field or by 
  a pop-up menu as shown in the Record panel.
*/

- setRateToMe:sender
    {
    NSString* defaultRate;
    float f;

    if ([sender isKindOfClass:[NSTextField class]])
	{
	f=[(NSControl*)sender floatValue];
	if (f<=0) f=SND_RATE_CODEC;		// default
	defaultRate=[NSString stringWithFormat:@"%f",f];
	}
    else
    defaultRate=[[sender selectedCell] title];

    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: defaultRate forKey: @"RecordRate"];
    }
    
    return self;
    }



/**** setFormatToMe:
  Sets the default format.  This is done in the record panel.
*/

- setFormatToMe:sender
    {
    NSString* defaultEncoding;
    int index;

    index=[[formatMenu menu] indexOfItem:[[formatMenu menu] itemWithTitle:[[sender selectedCell] title]]];

    defaultEncoding=[NSString stringWithFormat:@"%d",index];

    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: defaultEncoding forKey: @"RecordEncoding"];
    }
    
    return self;
    }




/**** setMono:
  Sets both volume channels.
*/

- setMono:sender
    {
    /* SndKit has no input gain device parameters (the 1998 code set
       NX_SoundDeviceInputGain* on the NXSoundIn); the gain sliders
       are display-only. */
    return self;
    }


/**** setLeft:
  Sets the left volume channel.
*/

- setLeft:sender
    {
    /* SndKit has no input gain device parameters (see setMono); the
       gain sliders are display-only. */
    return self;
    }


/**** setRight:
  Sets the right volume channel.
*/

- setRight:sender
    {
    /* SndKit has no input gain device parameters (see setMono); the
       gain sliders are display-only. */
    return self;
    }


/**** setMonoChannels:
  Sets the default number of channels to mono.
*/

- setMonoChannels:sender
    {
    NSString* defaultChannel;

    defaultChannel=@"1";

    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: defaultChannel forKey: @"RecordChannels"];
    }
    
    return self;
    }




/**** setStereoChannels:
  Sets the default number of channels to stereo.
*/


- setStereoChannels:sender
    {
    NSString* defaultChannel;

    defaultChannel=@"2";

    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: defaultChannel forKey: @"RecordChannels"];
    }
    
    return self;
    }



/**** setSourceMic:
  Sets the default source to the microphone (a PC option).
*/

- setSourceMic:sender
    {
    NSString* defaultSource;

    defaultSource=SOURCE_MIC;

    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: defaultSource forKey: @"RecordSource"];
    }
    
    return self;
    }




/**** setSourceLine:
  Sets the default source to line-input (a PC option).
*/


- setSourceLine:sender
    {
    NSString* defaultSource;

    defaultSource=SOURCE_LINE;

    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: defaultSource forKey: @"RecordSource"];
    }
    
    return self;
    }



/**** setRecordingLength:
  Sets the default recording length (the standard is F_LENGTH_5_MINUTES )
*/


- setRecordingLength:sender
    {
    NSString* defaultLength;
    float f=[sender floatValue];

    if (f<=0) f=F_LENGTH_5_MINUTES;	// default (we can't have negatives!)

    defaultLength=[NSString stringWithFormat:@"%f",f];
    [sender setStringValue:defaultLength];

    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: defaultLength forKey: @"RecordLength"];
    }
    
    return self;
    }



/**** windowDidBecomeKey:
  Set up initial matricies in record window...geez, this is dumb.
  */


- (void)windowDidBecomeKey:sender
/* This is really dumb--because I can't seem to pre-set the matrices,
   I have to set them after the window opens the first time */

    {
    NSString* defaultChannel;
    NSString* defaultSource;

    [sender disableFlushWindow];
    
    // Get Defaults

    {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        defaultChannel = [defaults stringForKey: @"RecordChannels"];
        defaultSource = [defaults stringForKey: @"RecordSource"];
     }

    // Set the Input Source...
    
    if ([defaultSource isEqualToString:SOURCE_LINE])
	[source selectCellAtRow:0 column:0];
    else 
	[source selectCellAtRow:1 column:0];
    

    if (input_format.channelCount==1)
	// Warning, bug in NeXT's docs the name is totally wrong...
	{
	[[channels cellAtRow:1 column:0] setEnabled:NO];
	[channels selectCellAtRow:0 column:0];
	defaultChannel=@"1";
	}
    else
	{
	if ([defaultChannel isEqualToString:@"1"])
	    [channels selectCellAtRow:0 column:0];
	else 
	    [channels selectCellAtRow:1 column:0];
	
	}
    [sender enableFlushWindow];
    [sender flushWindowIfNeeded];
    }


@end
