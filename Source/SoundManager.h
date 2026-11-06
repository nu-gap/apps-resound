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

This file was migrated from the defunct NeXT SoundKit to SndKit as part
of the GNUstep port (see docs/RESOUND_SNDKIT_PLAN.md, Phase 2, unit 1).
The Sound -> Snd rename and the performance-based delegate signatures
(below) are the substantive changes; the behaviour is unchanged.
Phase 2 unit 1b re-routed the recording flow: SndKit's Snd record: is
a stub and SndView documents recording as unsupported on any platform,
so record: now captures through SndStreamRecorder to a temp sound file
(unit 1b, see the notes in SoundManager.m); the Snd newSound is kept
only as the console meter's token object.
*/


#import <Foundation/Foundation.h>
#import <SndKit/SndKit.h>
#import <AppKit/NSWindow.h>

@interface SoundManager:NSObject
    {
    id  consoleManager;
    id  fileController;
    
    Snd*	currentPlayingOrRecordingSound;
    /* Typed as id for now: the soundview chain (MiscSoundView /
       ResoundMiscSoundView, hence SoundView -> SndView) is not yet
       migrated, so its headers still import <SoundKit/SoundKit.h> and
       cannot be used here.  All uses of the view below are dynamic
       message sends (play:/stop:/pause:/resume:/setPlayMark:), so the
       id type is safe.  Tighten to ResoundMiscSoundView* once the view
       chain is ported (Phase 2, next unit). */
    id	currentPlayingOrRecordingSoundView;
    NSWindow*	currentPlayingOrRecordingWindow;
    Snd*   newSound;
    /* Unit 1b: the capture itself runs through SndStreamRecorder (SndKit
       has no Snd-style capture); newSound above is only the console
       meter's token object.  These remember the capture so
       _finishRecording can close it, convert it to the requested
       format, and hand it off. */
    SndStreamRecorder* recorder;
    NSString* recordTempPath;
    int recordDataFormat;
    double recordSoundRate;
    int recordChannels;
    NSTimer* recordTimer;
    BOOL paused;
    BOOL playing;
    BOOL recording;
    }

- init;
- dealloc;
- (void)stop:(id)sender;				// Stop playing or recording.
- play:sender;		// Play the current sound.  Returns NULL if unable.
- record: (double) SoundRate: 
(int) channels: (int) DataSize: 
(int) dataFormat: sender;	      // Record a new sound.  Returns NULL if unable.
- (void) _finishRecording;           // Close the capture, convert, hand off.
                                     // Called by the duration timer and by
                                     // stop:; idempotent via the recording
                                     // flag.

- (int) togglePaused:sender;	    // Turns Pause on or off.  Returns 1 if now paused,
                                    // 2 if now not paused, or 0 if cannot toggle.
- (BOOL) isPlaying;						// Sound is Playing
- (BOOL) isRecording;					// Sound is Recording
- (BOOL) isPaused;						// Sound is Paused
- soundPlayingOrRecording;  // Returns the sound playing or recording, NULL if none.
                                 // Note this is the sound, not the soundview's
                                 // scratch sound actually being used.
- soundViewPlayingOrRecording;

/*---IMPLEMENTED AS A DELEGATE OF SOUND AND SOUNDVIEW-----*/

/* SndKit's delegate protocol (the SndDelegate class in Snd.h) differs
   from the old SoundKit in two ways: the playback-complete message
   gains a duringPerformance: argument (SndKit plays through
   SndPerformance objects), and an error message hadError: is added.
   didRecord: keeps its one-argument form in both. */

- didPlay:sender duringPerformance:performance;
- didRecord:sender;
- hadError:sender;

/* SndStreamRecorderDelegate (SndStreamRecorder.h): the capture-side
   analogue.  didStartRecording: is implemented as a no-op -- record:
   is synchronous, so no state change is needed (and it has not been
   observed to fire on this platform in the first place; see
   SoundManager.m).  didFinishRecording: is declared by SndKit but
   never sent, so there is nothing to implement. */

- didStartRecording:sender;

@end
