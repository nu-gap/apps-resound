/*
MiscSoundTracker
Version 2.0.2
Copyright (c) 1995, 1998 by Sean Luke
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

#import "MiscSoundTracker.h"
#import <stdio.h>

// SndKit has no Sound-style status enum (the NX_Sound* codes): the
// legacy stopped/initialized/freed group maps to "the sound has no
// active performance" (SndPerformance isPlaying covers the playing
// and pending members; isPaused the paused ones).  Snd's isRecording
// is a stub hard-wired NO, so there is no separate recording state
// to check.
static BOOL SOUNDTRACKER_sound_idle(Snd *snd)
	{
	NSArray* performances=[snd performances];
	int i;
	if ([snd isPlaying]) return NO;
	for (i=0;i<[performances count];i++)
		if ([[performances objectAtIndex:i] isPaused]) return NO;
	return YES;
	}

// SndKit has no samplesProcessed: the samples a performance has
// processed is its playIndex, exposed through
// samplesPerformedOfPerformance:.  A sound with no performance
// has processed none.
static int SOUNDTRACKER_samplesProcessed(Snd *snd)
	{
	SndPerformance* performance=[[snd performances] lastObject];
	if (performance==nil) return 0;
	return [snd samplesPerformedOfPerformance:performance];
	}

@implementation MiscSoundTracker

// KNOWN BUGS:  NeXT's sound object does not release sampling rate information
// properly.  Hence, the tracker cannot get seconds information correctly,
// when recording, and so must rely on a preset default for its sampling
// rate in returning seconds.

// also, samples do not keep up with pausing.



- init
	{
	[super init];
	running=NO;
	default_sampling_rate=SOUNDTRACKER_DEFAULT_SAMPLING_RATE;
	send_type=SOUNDTRACKER_SEND_TYPE_SAMPLES;
	refresh=SOUNDTRACKER_TIMED_ENTRY_SPEED;
	//printf ("Init\n");
	return self;
	}

- _update
	{
	//printf("Updating\n");
	
	// first we check to see if there's a sound lock and if so,
	// if we should proceed...
	
	if (sound!=nil&&
			(send_type==SOUNDTRACKER_SEND_TYPE_SAMPLES||
			send_type==SOUNDTRACKER_SEND_TYPE_RATIO||
			send_type==SOUNDTRACKER_SEND_TYPE_PERCENT||
			send_type==SOUNDTRACKER_SEND_TYPE_SECONDS))
			{
			id actual_sound;
			
			
			if ([sound isKindOfClass:[Snd class]])
				{actual_sound=sound;}
			else if ([sound isKindOfClass:[SndView class]])
				{actual_sound=[sound soundBeingProcessed];}
			else return nil;		// not a sound or soundview!!!
			
			// SndKit has no Sound-style status enum; the legacy
			// stopped/initialized/freed group maps to "no active
			// performance" (see the static above).
			if (SOUNDTRACKER_sound_idle((Snd*)actual_sound)) return self;
			}
	
	if (target!=nil)
		{
		//printf ("Target Not nil\n");
        if (send_type==SOUNDTRACKER_SEND_TYPE_SAMPLES||
            send_type==SOUNDTRACKER_SEND_TYPE_MUTE||		send_type==SOUNDTRACKER_SEND_TYPE_MUTE_SPEAKER||
            send_type==SOUNDTRACKER_SEND_TYPE_MUTE_LINE_OUT||
            send_type==SOUNDTRACKER_SEND_TYPE_MUTE_HEADPHONES||
            send_type==SOUNDTRACKER_SEND_TYPE_RAMPING||
			send_type==SOUNDTRACKER_SEND_TYPE_DEEMPHASIS)
			{
			//printf ("Sending Take Message\n");
			if (![target respondsToSelector:@selector(takeIntValueFrom:)])
				 return nil;
			[target takeIntValueFrom:self];
			}
		else if (send_type==SOUNDTRACKER_SEND_TYPE_RATIO||
				send_type==SOUNDTRACKER_SEND_TYPE_PERCENT)
			{
			// SndKit has no recording status on Snd (isRecording is a
			// stub hard-wired NO), so the legacy "clear the target
			// while recording" branch cannot fire; the target gets
			// the (zero) value as usual.
			if (![target respondsToSelector:@selector(takeFloatValueFrom:)])
				return nil;
			[target takeFloatValueFrom:self];
			}
		else if (send_type==SOUNDTRACKER_SEND_TYPE_SECONDS||
				send_type==SOUNDTRACKER_SEND_TYPE_LEFT||
				send_type==SOUNDTRACKER_SEND_TYPE_RIGHT||
				send_type==SOUNDTRACKER_SEND_TYPE_MONO||
           send_type==SOUNDTRACKER_SEND_TYPE_MONITOR_ATTENUATION)
			{
			if (![target respondsToSelector:@selector(takeFloatValueFrom:)])
				 return nil;
			[target takeFloatValueFrom:self];
			}
		else printf ("SOUNDTRACKER Error:  No Send Type\n");
		}
	return self;
	}


- setRefresh:(float) number_seconds
	{
	if (number_seconds>0)
		{
		refresh=number_seconds;
		if (teNum) 
			{
			[teNum invalidate]; 
			[teNum release];
			
			teNum = [[NSTimer timerWithTimeInterval:refresh 
							 target:self selector: @selector(SOUNDTRACKER_update_tracker:)
						       userInfo:(void*) nil 
							repeats:YES] retain];
        		   [[NSRunLoop currentRunLoop] addTimer:teNum forMode: NSDefaultRunLoopMode];  
			}
		}
	return self;
	}

- setRefreshToMe:sender
	{
	if ([sender respondsToSelector:@selector(floatValue)])
		[self setRefresh:[sender floatValue]];
	return self;
	}


- (float)refresh
	{
	return refresh;
	}	

- (void)dealloc
	{
	if (teNum) [teNum invalidate]; [teNum release];
	if (sound!=nil) [sound release];
	if (target!=nil) [target release];
	{ [super dealloc]; return; };
	}


- (void)setSound:(id)this_sound_or_soundview
	{
	if (sound!=nil) [sound release];
	sound=[this_sound_or_soundview retain];
	}
	

- sound
	{
	return sound;
	}

- setDefaultSamplingRate:(float) this_rate
	{
	if (this_rate!=0.0) default_sampling_rate=this_rate;
	return self;
	}

- (float)defaultSamplingRate
	{
	return default_sampling_rate;
	}
	
- (void)setTarget:this_target
	{
	if (target!=nil) [target release];
	target=[this_target retain];
	}


- target
	{
	return target;
	}

- clearTarget
        {
        if ([target respondsToSelector:@selector(setStringValue:)])
                {
                [target setStringValue:@""];
                }
        else [target setIntValue:0];
        return self;
        }

- (id)initWithCoder:(NSCoder *)aDecoder
        {
        //self = [super initWithCoder:aDecoder];  // NSObject Does not respont to initWithCoder
        [aDecoder decodeValuesOfObjCTypes:"iff",&send_type,&refresh,&default_sampling_rate];
        
	running=NO;
        teNum=0;
	return self;
        }

- (void)encodeWithCoder:(NSCoder *)aCoder
        {
        //[super encodeWithCoder:aCoder];  // NSObject Does not respond to encodeWithCoder
        [aCoder encodeValuesOfObjCTypes:"iff",&send_type,&refresh,&default_sampling_rate];
}

- (void)run
	{
	running=YES;
	if (!teNum) 
	{
	teNum = [[NSTimer timerWithTimeInterval:refresh 
					 target: self
			 	       selector: @selector(SOUNDTRACKER_update_tracker:)
 				       userInfo:(void*) self 
					repeats:YES] retain];
           [[NSRunLoop currentRunLoop] addTimer:teNum forMode: NSDefaultRunLoopMode]; 
	}
}


- stop
	{
	running=NO;
	if (teNum) 
	    	{
		[teNum invalidate]; 
		[teNum release];
		}
	teNum=0;
	return self;
	}


- sendSamples
	{
	send_type=SOUNDTRACKER_SEND_TYPE_SAMPLES;
	return self;
	}


- sendSeconds
	{
	send_type=SOUNDTRACKER_SEND_TYPE_SECONDS;
	return self;
	}


- sendRatio
	{
	send_type=SOUNDTRACKER_SEND_TYPE_RATIO;
	return self;
	}
	
- sendPercent
	{
	send_type=SOUNDTRACKER_SEND_TYPE_PERCENT;
	return self;
	}
	
- sendLeft
	{
	send_type=SOUNDTRACKER_SEND_TYPE_LEFT;
	return self;
	}
	

- sendRight
	{
	send_type=SOUNDTRACKER_SEND_TYPE_RIGHT;
	return self;
	}
	

- sendMono
	{
	send_type=SOUNDTRACKER_SEND_TYPE_MONO;
	return self;
	}
	

- sendMute
	{
	send_type=SOUNDTRACKER_SEND_TYPE_MUTE;
	return self;
	}
	
- sendDeemphasis
	{
	send_type=SOUNDTRACKER_SEND_TYPE_DEEMPHASIS;
	return self;
	}

- sendLeftPeak
	{
	send_type=SOUNDTRACKER_SEND_TYPE_LEFT_PEAK;
	return self;
	}

- sendRightPeak
	{
	send_type=SOUNDTRACKER_SEND_TYPE_RIGHT_PEAK;
	return self;
	}
	
- sendMonoPeak
	{
	send_type=SOUNDTRACKER_SEND_TYPE_MONO_PEAK;
	return self;
	}

- sendSpeakerMute	{
    send_type=SOUNDTRACKER_SEND_TYPE_MUTE_SPEAKER;
    return self;
    }

- sendLineOutMute	{
    send_type=SOUNDTRACKER_SEND_TYPE_MUTE_LINE_OUT;
    return self;
    }

- sendHeadphoneMute	{
    send_type=SOUNDTRACKER_SEND_TYPE_MUTE_HEADPHONES;
    return self;
    }

- sendRamping	{
    send_type=SOUNDTRACKER_SEND_TYPE_RAMPING;
    return self;
    }

- sendMonitorAttenuation	{
    send_type=SOUNDTRACKER_SEND_TYPE_MONITOR_ATTENUATION;
    return self;
    }

- setSendType:(int)this_format
	{
	if (this_format==SOUNDTRACKER_SEND_TYPE_SAMPLES||
		this_format==SOUNDTRACKER_SEND_TYPE_SECONDS||
		this_format==SOUNDTRACKER_SEND_TYPE_RATIO||
		this_format==SOUNDTRACKER_SEND_TYPE_PERCENT||
		this_format==SOUNDTRACKER_SEND_TYPE_LEFT||
		this_format==SOUNDTRACKER_SEND_TYPE_RIGHT||
		this_format==SOUNDTRACKER_SEND_TYPE_MONO||
		this_format==SOUNDTRACKER_SEND_TYPE_MUTE||
		this_format==SOUNDTRACKER_SEND_TYPE_DEEMPHASIS||
		this_format==SOUNDTRACKER_SEND_TYPE_LEFT_PEAK||
     this_format==SOUNDTRACKER_SEND_TYPE_RIGHT_PEAK||
     this_format==SOUNDTRACKER_SEND_TYPE_MONO_PEAK||
     this_format==SOUNDTRACKER_SEND_TYPE_MUTE_SPEAKER||
     this_format==SOUNDTRACKER_SEND_TYPE_MUTE_LINE_OUT||
     this_format==SOUNDTRACKER_SEND_TYPE_MUTE_HEADPHONES||
     this_format==SOUNDTRACKER_SEND_TYPE_RAMPING||
     this_format==SOUNDTRACKER_SEND_TYPE_MONITOR_ATTENUATION)
		{send_type=this_format;return self;}
	return nil;
	}

- (int) sendType
	{
	return send_type;
	}

- (float) floatValue	
	{
	if (send_type==SOUNDTRACKER_SEND_TYPE_SECONDS)
		{
		if (sound!=nil)
			{
			if ([sound isKindOfClass:[Snd class]])
				{
				float n=[(Snd*)sound samplingRate];
				//printf ("%f\n",n);
				if (n==0.0) n=default_sampling_rate;
				return (float)SOUNDTRACKER_samplesProcessed((Snd*)sound)/n;
				}
			else if ([sound isKindOfClass:[SndView class]])
				{
				id snd1=[sound soundBeingProcessed];
				float n=[(Snd*)snd1 samplingRate];
				//printf ("%f\n",n);
				if (n==0.0) n=default_sampling_rate;
				return (float)SOUNDTRACKER_samplesProcessed((Snd*)snd1)/n;
				}
			}
		}
	else if (send_type==SOUNDTRACKER_SEND_TYPE_RATIO)
		{
		if (sound!=nil)
			{
			if ([sound isKindOfClass:[Snd class]])
				{
				// SndKit: no status to gate on (see _update).
				return (float)SOUNDTRACKER_samplesProcessed((Snd*)sound)/
					(float)[(Snd*)sound lengthInSampleFrames];
				}
			else if ([sound isKindOfClass:[SndView class]])
				{
				id snd1=[sound soundBeingProcessed];
				// SndKit: no status to gate on (see _update).
				return (float)SOUNDTRACKER_samplesProcessed((Snd*)snd1)/
					(float)[(Snd*)snd1 lengthInSampleFrames];
				}
			}
		}
	else if (send_type==SOUNDTRACKER_SEND_TYPE_PERCENT)
		{
		if (sound!=nil)
			{
			if ([sound isKindOfClass:[Snd class]])
				{
				// SndKit: no status to gate on (see _update).
				return (float)SOUNDTRACKER_samplesProcessed((Snd*)sound)/
					(float)[(Snd*)sound lengthInSampleFrames]*100;
				}
			else if ([sound isKindOfClass:[SndView class]])
				{
				id snd1=[sound soundBeingProcessed];
				// SndKit: no status to gate on (see _update).
				return (float)SOUNDTRACKER_samplesProcessed((Snd*)snd1)/
					(float)[(Snd*)snd1 lengthInSampleFrames]*100;
				}
			}
		}
	else if (send_type==SOUNDTRACKER_SEND_TYPE_LEFT)
		{
		/* SndKit has no class-level volume (the legacy [Sound
		   getVolume:] was a device/global control; SndKit's volume is
		   per-performance, via SndAudioFader -- the VolumeController
		   unit picks that up); the send type is dormant. */
		return 0.0;
		}
	else if (send_type==SOUNDTRACKER_SEND_TYPE_RIGHT)
		{
		/* SndKit has no class-level volume (see the LEFT branch);
		   the send type is dormant. */
		return 0.0;
		}
	else if (send_type==SOUNDTRACKER_SEND_TYPE_MONO)
		{
		/* SndKit has no class-level volume (see the LEFT branch);
		   the send type is dormant. */
		return 0.0;
		}
    else if (send_type==SOUNDTRACKER_SEND_TYPE_MONITOR_ATTENUATION)
        {
        /* SndKit has no output device parameter API (the legacy read
           NX_SoundDeviceMonitorAttenuation on the NXSoundOut); the
           send type is dormant. */
        return -1.0;
        }
	else if (send_type==SOUNDTRACKER_SEND_TYPE_LEFT_PEAK)
		{
		/* SndKit has no output device peak API (the legacy read
		   NXSoundOut getPeakLeft:right:); the send type is dormant,
		   so the -1.0 below applies. */
		}
	else if (send_type==SOUNDTRACKER_SEND_TYPE_RIGHT_PEAK)
		{
		/* SndKit has no output device peak API (the legacy read
		   NXSoundOut getPeakLeft:right:); the send type is dormant,
		   so the -1.0 below applies. */
		}
	else if (send_type==SOUNDTRACKER_SEND_TYPE_MONO_PEAK)
		{
		/* SndKit has no output device peak API (the legacy read
		   NXSoundOut getPeakLeft:right:); the send type is dormant,
		   so the -1.0 below applies. */
		}

	else printf ("SOUNDTRACKER Error:  Wrong send type for floatValue\n");
	return -1.0;
	}


- (int) intValue	
	{
	//printf ("Okay\n");
	if (send_type==SOUNDTRACKER_SEND_TYPE_SAMPLES)
		{
		if (sound!=nil)
			{
			if ([sound isKindOfClass:[Snd class]])
				{
				return SOUNDTRACKER_samplesProcessed((Snd*)sound);
				}
			else if ([sound isKindOfClass:[SndView class]])
				{
				id snd1=[sound soundBeingProcessed];
				return SOUNDTRACKER_samplesProcessed((Snd*)snd1);
				}
			}
		}
	else if (send_type==SOUNDTRACKER_SEND_TYPE_MUTE)
		{
		return (int) [Snd isMuted];
		}
    else if (send_type==SOUNDTRACKER_SEND_TYPE_MUTE_SPEAKER)
        {
        /* SndKit has no output device parameter API (the legacy read
           NX_SoundDeviceMuteSpeaker on the NXSoundOut); the send type is dormant. */
        return NO;
        }
    else if (send_type==SOUNDTRACKER_SEND_TYPE_MUTE_LINE_OUT)
        {
        /* SndKit has no output device parameter API (the legacy read
           NX_SoundDeviceMuteLineOut on the NXSoundOut); the send type is dormant. */
        return NO;
        }
    else if (send_type==SOUNDTRACKER_SEND_TYPE_MUTE_HEADPHONES)
        {
        /* SndKit has no output device parameter API (the legacy read
           NX_SoundDeviceMuteHeadphone on the NXSoundOut); the send type is dormant. */
        return NO;
        }
    else if (send_type==SOUNDTRACKER_SEND_TYPE_RAMPING)
        {
        /* SndKit has no output device parameter API (the legacy read
           NX_SoundDeviceRampUp/RampDown on the NXSoundOut); the send type is dormant. */
        return NO;
        }
	else if (send_type==SOUNDTRACKER_SEND_TYPE_DEEMPHASIS)
		{
		/* SndKit has no output device parameter API (the legacy read
		   NXSoundOut doesDeemphasize); the send type is dormant. */
		return NO;
		}
	else printf ("SOUNDTRACKER Error:  Wrong send type for intValue\n");
	return -1;
	}


- setVolumeTo:sender	
	{
	float x;
	if (! [sender respondsToSelector:@selector(floatValue)]) return nil;
	x=[sender floatValue];
	if (x<0||x>1) return nil;
	/* SndKit has no class-level volume (the legacy [Sound getVolume:]/
	   [Sound setVolume:l:r:] were device/global controls; SndKit's
	   volume is per-performance, via SndAudioFader -- the
	   VolumeController unit picks that up) and no monitor-
	   attenuation parameter, so the volume send types are dormant. */
	return self;
	}


- setMuteTo:sender	
    {
    int x;
    if (! [sender respondsToSelector:@selector(intValue)]) return NULL;
    x=[sender intValue];
    if (x!=0) x=1;

    if (send_type==SOUNDTRACKER_SEND_TYPE_MUTE) [Snd setMute:(BOOL)x];
    /* SndKit has no output device parameter API (the legacy set
       NX_SoundDeviceMute* on the NXSoundOut); the speaker/
       line-out/headphone mute send types are dormant. */
    return self;
    }

- setDeemphasisTo:sender	
	{
	int x;
	if (! [sender respondsToSelector:@selector(intValue)]) return nil;
	x=[sender intValue];
	if (x!=0) x=1;
	
	/* SndKit has no output device parameter API (the legacy set
	   NXSoundOut setDeemphasis:); the deemphasis send types are
	   dormant. */
	return self;
	}


- setRampingTo:sender	
    {
    int x;
    if (! [sender respondsToSelector:@selector(intValue)]) return NULL;
    x=[sender intValue];
    if (x!=0) x=1;

    /* SndKit has no output device parameter API (the legacy set
       NX_SoundDeviceRampUp/RampDown on the NXSoundOut); the ramping
       send types are dormant. */
    return self;
    }

- (void)run:(id)sender
	{
	[self run];
	//return self;
	}


- (void)stop:(id)sender;
	{
	[self stop];
	}


- sendSamples:sender
	{
	return [self sendSamples];
	}


- sendSeconds:sender
	{
	return [self sendSeconds];
	}


- sendRatio:sender
	{
	return [self sendRatio];
	}

- sendPercent:sender
	{
	return [self sendPercent];
	}

- sendLeft:sender
	{
	return [self sendLeft];
	}

- sendRight:sender
	{
	return [self sendRight];
	}

- sendMono:sender
	{
	return [self sendMono];
	}

- sendMute:sender
	{
	return [self sendMute];
	}
	
- sendDeemphasis:sender
	{
	return [self sendDeemphasis];
	}
	
- sendLeftPeak:sender
	{
	return [self sendLeftPeak];
	}
	
- sendRightPeak:sender
	{
	return [self sendRightPeak];
	}	
	
- sendMonoPeak:sender
	{
	return [self sendMonoPeak];
	}

- sendSpeakerMute:sender
    {
    return [self sendSpeakerMute];
    }

- sendLineOutMute:sender
    {
    return [self sendLineOutMute];
    }

- sendHeadphoneMute:sender
    {
    return [self sendHeadphoneMute];
    }

- sendRamping:sender
    {
    return [self sendRamping];
    }

- sendMonitorAttenuation:sender
    {
    return [self sendMonitorAttenuation];
    }

- (NSString *)inspectorClassName
	{
	return @"MiscSoundTrackerInspector";
	}

// timed entry procedure for periodically updating
// This is called periodically when the NSTimer is Fired

-(void) SOUNDTRACKER_update_tracker: (id) theTimer
       {
       [self _update];
       }

@end






