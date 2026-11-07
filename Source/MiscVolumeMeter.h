/*

MiscVolumeMeter
 Version 2.0
 Copyright (c) 1995 by Sean Luke
 OpenStep / Rhapsody port
 Copyright (c) 1998 by Jerome Genest
 Donated to the MiscKit

 Permission to use, copy, modify, and distribute this material
 for any purpose and without fee, under the restrictions as noted
 in the MiscKit copyright notice, is hereby granted, provided that
 the MiscKit copyright notice and this permission notice
 appear in all source copies, and that the authors names shall not
 be used in advertising or publicity pertaining to this
 material without the specific, prior written permission
 of the author.  SEAN O. LUKE AMD JEROME GENEST  MAKE NO REPRESENTATIONS 
 ABOUT THE ACCURACY OR SUITABILITY OF THIS MATERIAL FOR ANY PURPOSE.
 IT IS PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.

 This file was migrated from the defunct NeXT SoundKit to SndKit as
 part of the GNUstep port (see docs/RESOUND_SNDKIT_PLAN.md, Phase 2,
 unit 1c, the console unit).  The legacy meter metered the *device*:
 NXSoundIn/NXSoundOut getPeakLeft:right: hardware peaks.  SndKit has
 no device object (and its own SndStreamClient setDetectPeaks:/
 getPeakLeft:right: are stubs that return self without touching the
 values), so the port computes the peaks from the meter's sound data
 over the window advanced since the previous refresh (see
 getPeakLeft:right: in the .m); the device ivars are gone.  The
 metered sound can be an Snd or an SndView, as in the legacy (the
 view's soundBeingProcessed accessor is the SndKit counterpart of the
 legacy SoundView's).
 */


#import <AppKit/AppKit.h>
#import <SndKit/SndKit.h>



// Defines

#define VOLUMEMETER_DISPLAYTYPE_NONE		0
#define VOLUMEMETER_DISPLAYTYPE_BEZEL		1

#define VOLUMEMETER_BACKGROUND_INSET 		2.0
#define VOLUMEMETER_VALUE_INSET			6.0
#define VOLUMEMETER_LEFT_END			0.4
#define VOLUMEMETER_RIGHT_BEGIN			0.6

#define VOLUMEMETER_TIMED_ENTRY_SPEED		0.1
#define VOLUMEMETER_MAX_REFRESHES		256
#define VOLUMEMETER_STD_REFRESHES		4



// Public Convenience Functions

BOOL VOLUMEMETER_can_draw(const NSRect* aRect);
	// given aRect, determines if there's enough space to draw a meter

BOOL VOLUMEMETER_draw_wide(const NSRect* aRect);
	// given aRect, determines if the meter should draw wide
	// (as opposed to tall)


@interface MiscVolumeMeter:NSView
{
	id		sound;			// can be a sound or soundview
	id		delegate;
	BOOL		input;			// set to input.  Default is NO
	BOOL		running;		// set running.  Default is NO
	BOOL		bezeled;
	BOOL		peak_bubble_displayed;
	BOOL		stereo;
	float		background_gray;
	float		value_gray;
	float		bubble_gray;
	float		refresh;
	int		refreshes_per_new_peak_bubble;
	int		refresh_tally;
	float		refreshes_left[VOLUMEMETER_MAX_REFRESHES];
	float		refreshes_right[VOLUMEMETER_MAX_REFRESHES];
	int		current_max_refresh_left;
	int		current_max_refresh_right;
	unsigned long last_position;	// the sound position the peak window
					// starts from (SndKit peaks, see .m)
	NSTimer *teNum;				// timed entry which displays
}


// constructors and destructors

- initWithFrame:(NSRect)frameRect;
- (void)dealloc;

// drawing

- (void)drawRect:(NSRect)rects;

// Setting parameters

- (void)setDelegate:(id)this_delegate;
- setMono;
- setStereo;
- setBackgroundGray:(float) this_value;	// 0 <= this_value <= 1
- setValueGray:(float) this_value;		// 0 <= this_value <= 1
- setBubbleGray:(float) this_value;		// 0 <= this_value <= 1
- (void)setBezeled:(BOOL)yes_or_no;
- setPeakBubbleDisplayed:(BOOL) yes_or_no;
- setToInput;				
- setToOutput;				
- setRefresh:(float) number_seconds;	// sets update speed in fraction of 
										// seconds or whole seconds.
										// default is .1 second
- setRefreshesPerNewPeakBubble:(int) number_refreshes;		
										// VOLUMEMETER_MAX_REFRESHES max, 1 min
// Querying the object

- delegate;
- (BOOL) isStereo:sender;
- (float) backgroundGray;
- (float) valueGray;
- (float) bubbleGray;
- (BOOL) isBezeled:sender;
- (BOOL) peakBubbleDisplayed:sender;
- (BOOL) isInput:sender;
- (float) refresh:sender;
- (int) refreshesPerPeakBubble:sender;

// Operating the meter

- reclaim;		// SndKit: no devices to reclaim (kept for the window
			// notifications); returns self.
- (void)run;
- stop;

// Archiving

- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;

// Locking Methods.  This locks the meter to only 
// display when a certain sound or soundview is recording or playing

- (void)setSound:(id)this_sound;	// can be a sound or a soundview
- sound;

// SndKit peak and channel hooks (used by drawRect:, overridable by
// subclasses; see the .m for the SndKit peak reader).

- (void) getPeakLeft:(float *) left right:(float *) right;
- (void) setChannelsForSound:(id)actual_sound;

// Action versions of above methods

- setMono:sender;
- setStereo:sender;
- setToInput:sender;
- setToOutput:sender;
- (void)run:(id)sender;
- (void)stop:(id)sender;

// Convenience methods responding to window action.
// This allows a window to open/close and start up / shut down the meter

- (void)windowDidBecomeKey:(NSNotification *)notification;
- (void)windowDidBecomeMain:(NSNotification *)notification;
- (void)windowDidDeminiaturize:(NSNotification *)notification;
- (void)windowDidMiniaturize:(NSNotification *)notification;
- (BOOL)windowShouldClose:(id)sender;



// Methods implementable by delegates of VolumeMeter:
// (VolumeMeter itself only defines them here--it doesn't do a thing with 'em)

- meterWillUpdateOnOwn:sender;	// ...the volume meter will update/display
				// (called before meterWillUpdate and before
				// the display method is called (so meter
				// has not locked focus yet))
- meterWillUpdate:sender;	//	...the volume meter will update/display
				// (possibly on its own)
- meterDidUpdate:sender;	//	...the volume meter updated/displayed
				// (possibly on its own)

@end
