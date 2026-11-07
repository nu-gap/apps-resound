/*

MiscSoundTracker
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

*/

/*
 This file was migrated from the defunct NeXT SoundKit to SndKit as
 part of the GNUstep port (see docs/RESOUND_SNDKIT_PLAN.md, Phase 2,
 unit 1c).  The sound can be an Snd or an SndView (the view's
 soundBeingProcessed accessor is the SndKit counterpart of the legacy
 SoundView's).  The legacy NXSoundOut output_device ivar is gone:
 SndKit has no output device object, and the device-parameter send
 types (peaks, mute channels, ramping, deemphasis, monitor
 attenuation) are dormant -- see the .m for what each now maps to
 (the global mute maps to [Snd setMute:], the sample counters to the
 Snd performance's playIndex).
 */

#import <AppKit/AppKit.h>
#import <SndKit/SndKit.h>
#import <Foundation/Foundation.h>


// defines

#define SOUNDTRACKER_SEND_TYPE_SAMPLES	1		// number of samples (int)
#define SOUNDTRACKER_SEND_TYPE_SECONDS	2		// number of seconds (float)
#define SOUNDTRACKER_SEND_TYPE_RATIO	3		// how far played (float 0-1)
#define SOUNDTRACKER_SEND_TYPE_PERCENT	4		// how far played (float 0-100)
#define SOUNDTRACKER_SEND_TYPE_LEFT	5		// left volume
#define SOUNDTRACKER_SEND_TYPE_RIGHT	6		// right volume
#define SOUNDTRACKER_SEND_TYPE_MONO		7		// mono volume
#define SOUNDTRACKER_SEND_TYPE_MUTE		8		// mute tracking
#define SOUNDTRACKER_SEND_TYPE_DEEMPHASIS	9	// deemphasis tracking
#define SOUNDTRACKER_SEND_TYPE_LEFT_PEAK	10	// left peak volume for device
#define SOUNDTRACKER_SEND_TYPE_RIGHT_PEAK	11	// right peak volume for device
#define SOUNDTRACKER_SEND_TYPE_MONO_PEAK	12	// average peak volume 

#define SOUNDTRACKER_SEND_TYPE_MUTE_SPEAKER 13  // monitor mute
#define SOUNDTRACKER_SEND_TYPE_MUTE_LINE_OUT 14 // line out mute
#define SOUNDTRACKER_SEND_TYPE_MUTE_HEADPHONES 15 // headphones mute
#define SOUNDTRACKER_SEND_TYPE_RAMPING 16 // ramping
#define SOUNDTRACKER_SEND_TYPE_MONITOR_ATTENUATION 17 // monitor attenuation

#define SOUNDTRACKER_TIMED_ENTRY_SPEED	2		// seconds between refreshes
#define SOUNDTRACKER_DEFAULT_SAMPLING_RATE 44100


@interface MiscSoundTracker:NSObject <NSCoding>
{
	id 			sound;			// can be an Snd or an SndView
	id 			target;			// item to send messages
	BOOL			running;		// is running
	int			send_type;		// what to send (see defines above)
	float			refresh;		// total seconds between updates
	NSTimer 		*teNum;			// timed entry
	float			default_sampling_rate;	// default rate for processing
}

- init;

- _update;						// message from timed entry
- setRefresh:(float) number_seconds;
- setRefreshToMe:sender;				// sender must respond to floatValue
- (float)refresh;
- (void)dealloc;

- (void)setSound:(id)this_sound_or_soundview;
- sound;
- setDefaultSamplingRate:(float) this_rate;	
		// because when recording, sound returns rate improperly
		// needed only to return seconds information.
		// cannot be 0.
- (float)defaultSamplingRate;
- (void)setTarget:this_target;
- target;
- clearTarget;	// make target display 0 or ""

- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;

- (void)run;
- stop;
- sendSamples;
- sendSeconds;
- sendRatio;
- sendPercent;
- sendLeft;
- sendRight;
- sendMono;
- sendMute;
- sendDeemphasis;
- sendLeftPeak;
- sendRightPeak;
- sendMonoPeak;
- sendSpeakerMute;
- sendLineOutMute;
- sendHeadphoneMute;
- sendRamping;
- sendMonitorAttenuation;

- setSendType:(int)this_format;
- (int)sendType;

- (float) floatValue;
- (int) intValue;

- setVolumeTo:sender;			// only used if tracking volume
- setMuteTo:sender;			// only used if tracking mute
- setDeemphasisTo:sender;		// only used if tracking deemphasis
- setRampingTo:sender;		// only used if tracking ramping

- (void)run:(id)sender;
- (void)stop:(id)sender;
- sendSamples:sender;
- sendSeconds:sender;
- sendRatio:sender;
- sendPercent:sender;
- sendLeft:sender;
- sendRight:sender;
- sendMono:sender;
- sendMute:sender;
- sendDeemphasis:sender;
- sendLeftPeak:sender;
- sendRightPeak:sender;
- sendMonoPeak:sender;
- sendSpeakerMute:sender;
- sendLineOutMute:sender;
- sendHeadphoneMute:sender;
- sendRamping:sender;
- sendMonitorAttenuation:sender;

-(void) SOUNDTRACKER_update_tracker:(id) theTimer;		// timed entry procedure for periodically updating

@end