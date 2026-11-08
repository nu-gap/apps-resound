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
  - Recording is re-routed through SndStreamRecorder (Phase 2 unit 1b):
    SndKit's Snd record: is a stub (it logs "Not yet implemented!") and
    SndView documents recording into the sound as unsupported on any
    platform, but SndStreamRecorder captures the native input stream to
    a file.  record: starts it with a -1.0 trigger threshold (the
    SndKit default 0.002 would wait for non-silence; the legacy
    SoundKit recorded whatever came in) into a temp .wav in the native
    input format, and an NSTimer enforces the legacy buffer-full
    duration (SndKit has no auto-stop: its
    prepareToRecordForDuration: ignores the duration, and the delegate's
    didFinishRecording: is declared but never sent).  _finishRecording
    (timer expiry or stop:) closes the file, reads it back with
    initFromSoundfile:, converts it to the console-requested format,
    and performs the legacy didRecord: handoff.  One deliberate
    behaviour change: a user stop during recording now hands off the
    partial capture (the legacy stop: discarded it).
    The newSound allocation stays: SndKit never fills it, so it serves
    as the console meter's token object (the meter shows a zero buffer,
    as in unit 1; the real meter re-work is a later unit).
  - The 1998 controller imports (FileController.h / ConsoleManager.h /
    ModuleController.h) were dropped in unit 1: those headers then still
    imported <SoundKit/SoundKit.h>, and FileController and
    ModuleController still do (later Phase 2 units).  ConsoleManager is
    ported (unit 1c) but its import stays dropped for now: the reference
    is the 1998 id, the pragma below covers the dispatch, and the file
    unit restores the 1998 import block as a whole.  All controller
    references are id-typed dynamic dispatch, so no headers are needed.
  - The diagnostic pragma below silences the -Wobjc-method-access
    warnings the id-typed controller dispatch above produces (the
    controllers' headers cannot be imported yet).  It no longer covers
    -Wobjc-multiple-method-names, whose reason is gone: SndKit declares
    play:/pause:/resume: on both Snd and SndView, which the unit-1
    id-typed view matched ambiguously -- but the view ivar is now the
    typed ResoundMiscSoundView (view-chain unit), so those sends resolve
    unambiguously and the suppression is dead weight.  Remove the pragma
    when the controllers are ported and the references can be typed
    again.
    (The -Wmissing-selector-name warnings from the 1998-style record:
    declaration are deliberately left visible: that idiom predates the
    port and its runtime selector is preserved exactly, see
    docs/GNUSTEP_BUILD.md.)
  
  ****************************************************************************/



#import "SoundManager.h"

#import <unistd.h>	/* getpid, for the capture temp file name */

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-method-access"

@implementation SoundManager


/*** init:
  initializes the Sound Manager
*/

- init
    {
    currentPlayingOrRecordingSoundView=nil;
    currentPlayingOrRecordingSound=nil;
    currentPlayingOrRecordingWindow=nil;
    recorder=nil;
    recordTempPath=nil;
    recordDataFormat=SND_FORMAT_UNSPECIFIED;
    recordSoundRate=0.0;
    recordChannels=0;
    recordTimer=nil;
    playing=NO;
    recording=NO;
    paused=NO;
    return self;
    }



/*** dealloc:
  Releases the capture resources.  The app holds the SoundManager for
  the whole session, so this only runs on abnormal teardown (for
  instance the console window closing mid-capture): stop the recorder
  (which flushes the buffer queue and closes the file) and delete the
  temp file.  No handoff happens here -- the objects that would receive
  the sound are being torn down as well.
*/

- (void) dealloc
    {
    if (recordTimer)
	{
	[recordTimer invalidate];
	[recordTimer release];
	recordTimer=nil;
	}
    if (recording&&recorder)
	[recorder stopRecording];
    if (recorder)
	{
	[recorder release];
	recorder=nil;
	}
    if (recordTempPath)
	{
	[[NSFileManager defaultManager] removeFileAtPath: recordTempPath handler: nil];
	[recordTempPath release];
	recordTempPath=nil;
	}
    [newSound release];
    newSound=nil;
    [super dealloc];
    }



/*** Stop:
  Stops the currently-playing sound or, if recording, finishes the
  capture (see _finishRecording).
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
	/* The capture runs through the SndStreamRecorder (newSound is
	   only the meter token), so stopping it is a recorder
	   operation; _finishRecording does the stop, the read-back
	   conversion, and the legacy didRecord: handoff in one pass.
	   (Behaviour note: the legacy stop: discarded a partial
	   capture; the port hands it off -- see the notes at the top.) */
	[self _finishRecording];
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
	/* SndKit has no Sound-style capture (Snd record: is a stub and
	   SndView documents recording into the sound as unsupported), so the
	   capture runs through the SndStreamRecorder (unit 1b, see the notes
	   at the top).  The newSound allocation stays: SndKit never fills
	   it, so it is the console meter's token object.  As in unit 1 the
	   buffer is sized at init (the legacy Sound built it with
	   setDataSize:dataFormat:samplingRate:channelCount:infoSize:); the
	   console passes the buffer size in bytes, so the frame count is
	   the byte count over the per-frame size (channels * sample width). */
	int sampleWidth = SndSampleWidth ((SndSampleFormat) dataFormat);
	unsigned long frames = 0;
	if (channels > 0 && sampleWidth > 0)
	    frames = (unsigned long) dataSize / ((unsigned long) channels * (unsigned long) sampleWidth);
	
	newSound = [[Snd alloc] initWithFormat: (SndSampleFormat) dataFormat
                                  channelCount: channels
                                        frames: frames
                                samplingRate: soundRate];
	
	/* The real capture.  No +streamRecorder factory exists in SndKit
	   (doc comment only), hence alloc/init. */
	recorder = [[SndStreamRecorder alloc] init];
	[recorder setDelegate: self];
	/* The recorder starts writing only when a sample exceeds the
	   trigger threshold (SndKit default 0.002f); the legacy SoundKit
	   recorded whatever came in for the buffer duration, so a
	   non-positive threshold preserves that (and is what lets a
	   digital-silence input record at all). */
	[recorder setStartTriggerThreshold: -1.0f];
	
	/* The capture file, in the native input format.  .wav keeps the
	   temp file openable by other tools (.aiff is 1-2 channel capped
	   through libsndfile; .snd is SndKit's own container). */
	recordTempPath = [[NSTemporaryDirectory()
	    stringByAppendingPathComponent:
		[NSString stringWithFormat: @"resound-record-%d.wav", (int) getpid()]] retain];
	
	if (![recorder startRecordingToFile: recordTempPath])
	    {
	    /* No usable input: roll back and report "cannot record" the
	       same way the legacy guard does. */
	    [recordTempPath release];
	    recordTempPath=nil;
	    [recorder release];
	    recorder=nil;
	    [newSound release];
	    newSound=nil;
	    return nil;
	    }
	
	/* Remember the console-requested format; the capture itself is in
	   the native input format and is converted in _finishRecording. */
	recordDataFormat = dataFormat;
	recordSoundRate = soundRate;
	recordChannels = channels;
	
	[consoleManager setDefaultChannelCount:channels]; // for ResoundMiscVolumeMeter 
	[consoleManager setMeterTo: newSound];
	[consoleManager startMeter];
	recording=YES;
	playing=NO;
	paused=NO;
	[[fileController getModuleController] soundNowRecording];
	
	/* SndKit has no buffer-full auto-stop, so the app enforces the
	   legacy capture duration: the console's buffer byte size is the
	   legacy full-capture size, hence the timer interval is the byte
	   count over the per-second byte rate. */
	if (frames > 0 && soundRate > 0 && channels > 0)
	    {
	    double duration = (double) dataSize / ((double) channels * (double) sampleWidth * soundRate);
	    if (duration > 0.0)
		recordTimer = [NSTimer scheduledTimerWithTimeInterval: duration
		                                               target: self
		                                             selector: @selector(_finishRecording)
		                                             userInfo: nil
		                                              repeats: NO];
	    }
	return self;
	}
    return nil;
    }



/*** _finishRecording:
  Completes the SndStreamRecorder capture (unit 1b, see the notes at
  the top): stops the recorder (which flushes and closes the temp file),
  reads the capture back, converts it to the console-requested format,
  and does the legacy didRecord: handoff (consoleManager stopDown:
  drives the shared stop: cleanup; fileController newRecordedSound:
  takes the sound; the module is told).  Called by the duration timer
  and by stop:.  Idempotent via the recording flag, which is cleared
  first, so the other entry point -- and a late-firing one-shot timer --
  is a no-op.
*/

- (void) _finishRecording
    {
    if (!recording)
	return;
    recording=NO;
    
    if (recorder)
	[recorder stopRecording];
    
    /* Read the capture back and convert it from the native input
       format to the console-requested format (the only conversion the
       flow needs; a same-rate convert takes the cheap memmove path).
       If the read-back fails, the newSound token stays the object the
       legacy didRecord: handed off. */
    Snd* recorded=nil;
    if (recordTempPath)
	recorded = [[Snd alloc] initFromSoundfile: recordTempPath];
    if (recorded)
	{
	[recorded convertToSampleFormat: (SndSampleFormat) recordDataFormat
			  samplingRate: recordSoundRate
			  channelCount: recordChannels];
	[newSound release];
	newSound = recorded;
	}
    
    playing=NO;
    paused=NO;
    [consoleManager stopDown: self];
    [fileController newRecordedSound: [newSound autorelease]];
    [[fileController getModuleController] soundDidRecord];
    
    if (recordTempPath)
	{
	[[NSFileManager defaultManager] removeFileAtPath: recordTempPath handler: nil];
	[recordTempPath release];
	recordTempPath=nil;
	}
    if (recorder)
	{
	[recorder release];
	recorder=nil;
	}
    if (recordTimer)
	{
	[recordTimer invalidate];
	[recordTimer release];
	recordTimer=nil;
	}
    //return self;
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
  Legacy SoundKit completion: the sound finished recording into its
  buffer.  Vestigial since unit 1b -- SndKit's Snd record: is a stub
  and SoundManager no longer calls it, so Snd never sends this (the
  capture now completes through _finishRecording).  Kept so the
  delegate surface still matches the legacy class.
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


/*** didStartRecording:
  SndStreamRecorderDelegate (SndStreamRecorder.h): sent from the
  stream thread when the recorder is about to start capturing.
  Implemented as a no-op: record: is synchronous (recording is set
  there), so no state change is needed.  It has not been observed to
  fire on this platform in probe runs, which is why completion is
  timer/stop-driven, not delegate-driven (SndKit's
  didFinishRecording: is declared but never sent).
*/

- didStartRecording:sender
    {
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

