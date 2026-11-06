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

  SoundManager.[h|m]
  Sean Luke
  
  SoundManager handles recording and playing sounds.  It works so closely with
  consoleManager that really the two should just be rolled into the same object.

  One important note:  SoundManager is the de facto delegate of all SoundViews and Sounds.
  So if you roll this one into the consoleManager etc., be sure to change
  all the delegate statements throughout the code (mostly here and in fileController).
  
  SndKit migration notes (GNUstep port, docs/RESOUND_SNDKIT_PLAN.md Phase 2):
  - Sound -> Snd throughout.
  - SndKit has no Sound-style setDataSize:dataFormat:samplingRate:
    channelCount:infoSize:; the size of the recording buffer is set at
    init instead (initWithFormat:channelCount:frames:samplingRate:), with
    the frame count derived from the byte size the console panel passes.
    (The old infoSize: argument had no counterpart: Snd's info is an
    unbounded NSString.)
  - The playback-complete delegate message gains the SndKit
    duringPerformance: argument (see the header for details).
  - The FileController/ConsoleManager/ModuleController imports were
    dropped: those headers still import <SoundKit/SoundKit.h> (they are
    later Phase 2 units).  SoundManager holds only id references to them
    and messages them dynamically, so no headers are needed.  Re-add
    them for static type-checking as those classes are ported.
  - The two diagnostic pragmas below silence exactly the warning classes
    that the id dispatch above produces: -Wobjc-method-access (sends to
    controllers whose headers cannot be imported yet) and
    -Wobjc-multiple-method-names (SndKit declares play:/pause:/resume:
    on both Snd and SndView, which an id-typed view matches
    ambiguously).  Remove the pragmas when the view chain and the
    controllers are ported and the references can be typed again.
    (The -Wmissing-selector-name warnings from the 1998-style record:
    declaration are deliberately left visible: that idiom predates the
    port and its runtime selector is preserved exactly, see
    docs/GNUSTEP_BUILD.md.)
  
  ****************************************************************************/



#import "SoundManager.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-method-access"
#pragma clang diagnostic ignored "-Wobjc-multiple-method-names"

@implementation SoundManager


/*** init:
  initializes the Sound Manager
*/

- init
    {
    currentPlayingOrRecordingSoundView=nil;
    currentPlayingOrRecordingSound=nil;
    currentPlayingOrRecordingWindow=nil;
    playing=NO;
    recording=NO;
    paused=NO;
    return self;
    }



/*** Stop:
  Stops the currently-playing sound.
 */

- (void)stop:(id)sender;
    {
    if (playing)
	{
	[currentPlayingOrRecordingSoundView stop:self];
	[fileController setPlaying:currentPlayingOrRecordingWindow:NO];
	[[fileController getModuleController] soundDidPlay];
	}
    else if (recording)
	{
	[newSound stop:self];
	[[fileController getModuleController] soundDidRecord];
	}
    
    [consoleManager stopMeter];
    currentPlayingOrRecordingSoundView=nil;
    currentPlayingOrRecordingSound=nil;
    currentPlayingOrRecordingWindow=nil;
    playing=NO;
    recording=NO;
    paused=NO;
    //return self;
    }




/***
  Begins playing the current Sound and SoundView.
*/

- play:sender
    {
    currentPlayingOrRecordingSoundView=[fileController currentSoundView:self];
    currentPlayingOrRecordingSound=[fileController currentSound:self];
    currentPlayingOrRecordingWindow=[fileController currentWindow:self];
    if (!playing&&!recording)
	{
	if (currentPlayingOrRecordingSoundView!=nil&&currentPlayingOrRecordingSound!=nil)		// sound exists to play
	    {
	    if ([currentPlayingOrRecordingSound dataFormat]!=SND_FORMAT_UNSPECIFIED)		// a known sound
		{
		[currentPlayingOrRecordingSoundView play:self];
		[consoleManager setMeterTo:[currentPlayingOrRecordingSoundView soundBeingProcessed]];
		[consoleManager startMeter];
		[fileController setPlaying:currentPlayingOrRecordingWindow:YES];
		playing=YES;
		recording=NO;
		paused=NO;
		[[fileController getModuleController] soundNowPlaying];
		return self;
		}
	    }
	}
    // else	
    return nil;
    }




/*** TogglePaused:
  Pauses/unpauses a playing sound.
*/

- (int) togglePaused:sender
    {
    if (playing==YES)
	{
	if (paused==NO) {[currentPlayingOrRecordingSoundView pause:self]; paused=YES; return 1;}
	else {[currentPlayingOrRecordingSoundView resume:self]; paused=NO; return 2;}
	}
    else return 0;
    }




/*** Record:::::
  Records and returns a new sound with the given parameters.
*/

- record: (double) soundRate: (int) channels: (int) dataSize: (int) dataFormat: sender
    {
    if (!playing&&!recording)
	{
	/* SndKit sizes the recording buffer at init time (the legacy
	   Sound built it with setDataSize:dataFormat:samplingRate:
	   channelCount:infoSize:).  The console passes the buffer size
	   in bytes; the corresponding frame count is the byte count
	   divided by the per-frame size (channels * sample width). */
	int sampleWidth = SndSampleWidth ((SndSampleFormat) dataFormat);
	unsigned long frames = 0;
	if (channels > 0 && sampleWidth > 0)
	    frames = (unsigned long) dataSize / ((unsigned long) channels * (unsigned long) sampleWidth);
	
	newSound = [[Snd alloc] initWithFormat: (SndSampleFormat) dataFormat
                                 channelCount: channels
                                       frames: frames
                               samplingRate: soundRate];
	[newSound setDelegate:self];
	
	[newSound record:self];
	[consoleManager setDefaultChannelCount:channels]; // for ResoundMiscVolumeMeter 
	[consoleManager setMeterTo: newSound];
	[consoleManager startMeter];
	recording=YES;
	playing=NO;
	paused=NO;
	[[fileController getModuleController] soundNowRecording];
	return self;
	}
    return nil;
    }



/*** isPlaying
  Returns true if a sound is playing.
*/

- (BOOL) isPlaying
    {
    return playing;
    }


/*** isRecording
  Returns true if a sound is recording.
*/

- (BOOL) isRecording
    {
    return recording;
    }


/*** isPaused
  Returns true if a sound is paused while playing.
*/

- (BOOL) isPaused
    {
    return paused;
    }

/*** SoundPlayingOrRecording
  Returns the sound currently playing or recording.
*/

- soundPlayingOrRecording
    {
    return currentPlayingOrRecordingSound;
    }



/*** SoundViewPlayingOrRecording
  Returns the SoundView currently playing or recording.
*/

- soundViewPlayingOrRecording
    {
    return currentPlayingOrRecordingSoundView;
    }




// DELEGATE METHODS


/*** didPlay:
  Cleans up after a sound finished playing.  Informs the Console Manager, 
  Module Controller, etc.

  SndKit: the soundview forwards the completion of its Snd to its
  delegate with the performance as an extra argument (the old SoundKit
  had no performances).  The argument is not used here yet.
*/

- didPlay:sender duringPerformance:(SndPerformance *) performance
    {
    // assumes sender is a soundview
    [sender setPlayMark:-1];
    [consoleManager stopDown:self];
    playing=NO;
    recording=NO;
    paused=NO;
    [[fileController getModuleController] soundDidPlay];
    return self;
    }

/*** didRecord:
  Cleans up after a sound finished recording.  Informs the Console Manager, 
  Module Controller, etc.  Hands the sound to the fileController to pop up on
  the screen.
*/

- didRecord:sender
    {
    playing=NO;
    recording=NO;
    paused=NO;
    [consoleManager stopDown:self];
    [fileController newRecordedSound: [newSound autorelease]];
    [[fileController getModuleController] soundDidRecord];
    return self;
    }



/*** hadError:
  New with SndKit: the framework notifies the delegate when an error
  occurs during playback or recording (the legacy app had no error
  path).  Clean up as in stop:, and tell the module controller that
  whatever was active has ended.
*/

- hadError:sender
    {
    BOOL wasRecording = recording;
    [consoleManager stopMeter];
    currentPlayingOrRecordingSoundView=nil;
    currentPlayingOrRecordingSound=nil;
    currentPlayingOrRecordingWindow=nil;
    playing=NO;
    recording=NO;
    paused=NO;
    if (wasRecording)
	[[fileController getModuleController] soundDidRecord];
    else
	[[fileController getModuleController] soundDidPlay];
    return self;
    }



/*** selectionChanged:
  A delegate method that the ResoundMiscSoundView needs.  So when I receive it (I'm
  the delegate of all SoundViews), I bounce it back to a ResoundMiscSoundView method.
*/

- selectionChanged:sender			
    {
    return [sender updateStuff];
    }

/*** soundDidChange:
  FileConroller needs this one, so I forward it to the appropriate fileController
  method.  This assumes that the sender is the current sound!  Modules should not
  be fooling around with anything but the current sound and soundview.
*/

- soundDidChange:sender
    {
    return [fileController soundChanged: [fileController currentSound:self]];
    }

@end

#pragma clang diagnostic pop

