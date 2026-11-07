/*

MiscVolumeMeter
 Version 2.0.2
 Copyright (c) 1995,1998 by Sean Luke
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

#import "MiscVolumeMeter.h"
#import <stdio.h>
#import <math.h>


// convenience functions

BOOL VOLUMEMETER_draw_wide(const NSRect* aRect)
       {
       return (BOOL) (aRect->size.width>=aRect->size.height);
       }

BOOL VOLUMEMETER_can_draw(const NSRect* aRect)
       {
       return (BOOL) (aRect->size.width>VOLUMEMETER_VALUE_INSET*2
               &&aRect->size.height>VOLUMEMETER_VALUE_INSET*2);
       }





// SndKit has no Sound-style status enum (the NX_Sound* codes).
// SndPerformance's isPlaying covers the legacy NX_SoundPlaying and
// NX_SoundPlayingPending group (a pending performance has not reached
// its end, so it counts as playing); isPaused covers the paused
// members.  Snd's isRecording is hard-wired NO (SndKit never records
// into an Snd), so the legacy recording group is undetectable on an
// Snd: such a sound reports idle and the meter erases its bar (the
// legacy bar in that state was driven by the input device's peaks,
// which has no SndKit counterpart).
static BOOL VOLUMEMETER_sound_idle(Snd *snd)
	{
	NSArray* performances;
	int i;
	if ([snd isPlaying]) return NO;
	performances=[snd performances];
	for (i=0;i<[performances count];i++)
		if ([[performances objectAtIndex:i] isPaused]) return NO;
	return YES;
	}


@implementation MiscVolumeMeter

// slave method to the below timed entry function

- _update
	{
	if ([delegate respondsToSelector:@selector(meterWillUpdateOnOwn:)])
		[delegate meterWillUpdateOnOwn:self];
	[self display];
	return self;
	}


// Call periodically when the NSTimer id fired

- (void)VOLUMEMETER_update_meter: (id) theTimer
	{
	//printf ("Display!\n");
	[self _update];
	}


// methods

- initWithFrame:(NSRect)frameRect
	{
	int x;
	
	[super initWithFrame:frameRect];
	
	delegate=NULL;
	input=NO;
	running=NO;
	bezeled=YES;
	peak_bubble_displayed=YES;
	stereo=YES;
	background_gray=NSDarkGray;
	value_gray=NSLightGray;
	bubble_gray=NSWhite;
	refresh=VOLUMEMETER_TIMED_ENTRY_SPEED;
	refreshes_per_new_peak_bubble=VOLUMEMETER_STD_REFRESHES;
	refresh_tally=0;
	for (x=0;x<VOLUMEMETER_MAX_REFRESHES;x++) 
		{refreshes_left[x]=0.0;refreshes_right[x]=0.0;}
	current_max_refresh_left=0;
	current_max_refresh_right=0;
	
	last_position=0;
	teNum=0;
	
	return self;
	}
	
- (void)drawRect:(NSRect)rects
	{
	NSRect drawRectLeft,drawRectRight;
	NSRect backgroundRect=[self bounds];
	NSRect valueRect=[self bounds];
	NSRect theBounds =[self bounds];
	float left,right;
	int just_erase=0;
	
	//if (![window isVisible]) return NULL;		// no window to draw in.
	// the above has been turned off because when loading Resound,
	// the sound meter wouldn't display until a sound was being played
	// or recorded!
	
	if ([delegate respondsToSelector:@selector(meterWillUpdate:)])
		[delegate meterWillUpdate:self];
	
	// first to check to see if the sound lock is current
	//printf ("Meter\n");
	if (sound!=NULL)
		{
		id actual_sound=NULL;			// quiets compiler complaints
		
		// The metered sound can be an Snd or an SndView (the view's
		// soundBeingProcessed accessor is the SndKit counterpart of the
		// legacy SoundView's; the cast is for the OS X server).
		if ([sound isKindOfClass:[Snd class]]) 
			{actual_sound=sound;}
		else if ([sound isKindOfClass:[SndView class]])
			{actual_sound=[sound soundBeingProcessed];}
		
		// SndKit has no Sound-style status enum; the performance flags
		// cover the legacy NX_Sound* groups (see the static above).  An
		// idle sound erases the bar; the legacy recording group is
		// undetectable on an Snd and erases likewise.  Everything else
		// meters the output.
		if (actual_sound==NULL
			||VOLUMEMETER_sound_idle((Snd*)actual_sound))
			{just_erase=1;}
		else
			{[self setToOutput];}
		
		// Then set the channel mode to match the sound (a hook:
		// ResoundMiscVolumeMeter overrides the channel-count fallback).
		[self setChannelsForSound:actual_sound];
		
		}
	
	// then check for bezeled stuff
	
	
	if (bezeled)
		{
		backgroundRect.origin.x		+=VOLUMEMETER_BACKGROUND_INSET; 
		backgroundRect.size.width	-=VOLUMEMETER_BACKGROUND_INSET*2;
		backgroundRect.origin.y		+=VOLUMEMETER_BACKGROUND_INSET; 
		backgroundRect.size.height	-=VOLUMEMETER_BACKGROUND_INSET*2;
		
		valueRect.origin.x		+=VOLUMEMETER_VALUE_INSET;
		valueRect.size.width 		-=VOLUMEMETER_VALUE_INSET*2;
		valueRect.origin.y		+=VOLUMEMETER_VALUE_INSET;
		valueRect.size.height		-=VOLUMEMETER_VALUE_INSET*2;
		}
	else
		{
		valueRect.origin.x	+=
				VOLUMEMETER_VALUE_INSET-VOLUMEMETER_BACKGROUND_INSET;
		valueRect.size.width 	-=
				VOLUMEMETER_VALUE_INSET*2-VOLUMEMETER_BACKGROUND_INSET*2;
		valueRect.origin.y	+=
				VOLUMEMETER_VALUE_INSET-VOLUMEMETER_BACKGROUND_INSET;
		valueRect.size.height	-=
				VOLUMEMETER_VALUE_INSET*2-VOLUMEMETER_BACKGROUND_INSET*2;
		}
	
	if (!VOLUMEMETER_can_draw(&theBounds)) return;	// can't draw
	
	if (bezeled) NSDrawGrayBezel(theBounds , theBounds);
	PSsetgray(background_gray);
	NSRectFill(backgroundRect);
	
	if (just_erase) return;
	
	// compute for drawing
	
	if (running)
		{
		left=0;right=0;
		
		// SndKit: peaks from the metered sound's data (see
		// getPeakLeft:right:); the legacy read the input or output
		// device's hardware peaks depending on the input flag.
		[self getPeakLeft:&left right:&right];
			
		if (left>1) left=1; if (right>1) right=1;
			// occasionally a NeXTSTEP bug returns values larger than 1!
		
		// perform refresh computations
		
		if (++refresh_tally>=refreshes_per_new_peak_bubble) refresh_tally=0;
		refreshes_left[refresh_tally]=left;
		refreshes_right[refresh_tally]=right;
		if (left>=refreshes_left[current_max_refresh_left])
	
	// remember, this might simply be because left stepped on the old champion!
	// ...search for new champion
	
			{
			int y;
			int maxpos=0;
			for (y=0;y<refreshes_per_new_peak_bubble;y++)
				if (refreshes_left[y]>refreshes_left[maxpos]) maxpos=y;
			current_max_refresh_left=maxpos;
			}
		if (right>=refreshes_right[current_max_refresh_right])
			// same as above!
			// ...search for new champion
			{
			int y;
			int maxpos=0;
			for (y=0;y<refreshes_per_new_peak_bubble;y++)
				if (refreshes_right[y]>refreshes_right[maxpos]) maxpos=y;
			current_max_refresh_right=maxpos;
			}
		
		// Draw away...
			
		if (VOLUMEMETER_draw_wide(&valueRect))		// draw wide
			{
				
			if (stereo)
				{
				
				// note that right and left are flipped,
				// so that when displaying wide, left is on the top.
				
				drawRectRight=valueRect;
				drawRectRight.size.height*=1-VOLUMEMETER_RIGHT_BEGIN;
				drawRectRight.origin.y+=valueRect.size.height*
						VOLUMEMETER_RIGHT_BEGIN;
				drawRectRight.size.width*=left;
			
				drawRectLeft=valueRect;
				drawRectLeft.size.height*=VOLUMEMETER_LEFT_END;
				drawRectLeft.size.width*=right;
				}
			else
				{
				drawRectRight=valueRect;
				drawRectRight.size.width*=(right+left)/2.0;
				}
			}
		else										// draw tall
			{
			
			if (stereo)
				{
				drawRectRight=valueRect;
				drawRectRight.size.width*=1-VOLUMEMETER_RIGHT_BEGIN;
				drawRectRight.origin.x+=valueRect.size.width*
						VOLUMEMETER_RIGHT_BEGIN;
				drawRectRight.size.height*=right;
			
				drawRectLeft=valueRect;
				drawRectLeft.size.width*=VOLUMEMETER_LEFT_END;
				drawRectLeft.size.height*=left;
				}
			else
				{
				drawRectRight=valueRect;
				drawRectRight.size.height*=(right+left)/2.0;
				}
			}
		if (left+right>0.0)			
		
		// I go through the computation because peak bubbles need it
		
			{
			PSsetgray(value_gray);
			NSRectFill(drawRectRight);
			if (stereo) NSRectFill(drawRectLeft);
			}
		// Draw Peak Bubbles			

		if (peak_bubble_displayed)
			{
			NSRect rightRect=drawRectRight;
			NSRect leftRect=drawRectLeft;
			float max_left=refreshes_left[current_max_refresh_left];
			float max_right=refreshes_right[current_max_refresh_right];
			
			if (max_left+max_right>0.0)
				{
			
				if (VOLUMEMETER_draw_wide(&valueRect))		// draw wide
					{
					rightRect.size.width=0.1;			// ...makes it a line
					leftRect.size.width=0.1;
					
					if (stereo)
						{
						rightRect.origin.x=floor(drawRectRight.origin.x+
							valueRect.size.width*max_left);
						leftRect.origin.x=floor(drawRectLeft.origin.x+
							valueRect.size.width*max_right);
						}
					else
						{
						rightRect.origin.x=floor(drawRectRight.origin.x+
							valueRect.size.width*
							(max_right+max_left)/2.0);
						}
					}	
				else						// draw tall
					{
					rightRect.size.height=0.1;		// makes it a line
					leftRect.size.height=0.1;
					
					if (stereo)
						{
						rightRect.origin.y=floor(drawRectRight.origin.y+
							valueRect.size.height*max_right);
						leftRect.origin.y=floor(drawRectLeft.origin.y+
							valueRect.size.height*max_left);
						}
					else
						{
						rightRect.origin.y=floor(drawRectRight.origin.y+
							valueRect.size.height*
							(max_right+max_left)/2.0);
						}
					}
				PSsetgray(bubble_gray);
				NSRectFill(rightRect);
				if (stereo) NSRectFill(leftRect);
				}
			}
		}
	PSWait();
	if ([delegate respondsToSelector:@selector(meterDidUpdate:)])
		[delegate meterDidUpdate:self];
}


- setMono
	{
	stereo=NO;
	//[self display];
	return self;
	}
	
- setStereo
	{
	stereo=YES;
	//[self display];
	return self;
	}

- setBackgroundGray:(float) this_value
	{
	if (this_value>=0&&this_value<=1) background_gray=this_value;
	[self display];
	return self;
	}

- setValueGray:(float) this_value
	{
	if (this_value>=0&&this_value<=1) value_gray=this_value;
	[self display];
	return self;
	}

- setBubbleGray: (float) this_value
	{
	if (this_value>=0&&this_value<=1) bubble_gray=this_value;
	[self display];
	return self;
	}

- (float) backgroundGray
	{
	return background_gray;
	}

- (float) valueGray
	{
	return value_gray;
	}

- (float) bubbleGray
	{
	return bubble_gray;
	}

- (void)setBezeled:(BOOL)yes_or_no
	{
	bezeled=yes_or_no;
	[self display];
}

- setPeakBubbleDisplayed:(BOOL) yes_or_no
	{
	peak_bubble_displayed=yes_or_no;
	[self display];
	return self;
	}

- setToInput
	{
	input=YES;
	/* SndKit has no device to reclaim or test (see reclaim). */
	return self;
	}

- setToOutput
	{
	input=NO;
	/* SndKit has no device to reclaim or test (see reclaim). */
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
							 target:self 
				     		       selector:@selector (VOLUMEMETER_update_meter:) 
				       		       userInfo:(void*) self repeats:YES] retain];

        		[[NSRunLoop currentRunLoop] addTimer:teNum forMode:NSDefaultRunLoopMode];
       						 // NSDefaultRunLoopMode or NSModalPanelRunLoopMode
			}
		}
	return self;
	}
	
- setRefreshesPerNewPeakBubble:(int) number_refreshes
	{
	if (number_refreshes<=VOLUMEMETER_MAX_REFRESHES&&number_refreshes>0)
		{
		int x;
		refreshes_per_new_peak_bubble=number_refreshes;
		for (x=0;x<number_refreshes;x++) 
			{refreshes_left[x]=0.0;refreshes_right[x]=0.0;}
		current_max_refresh_left=0;
		current_max_refresh_right=0;
		refresh_tally=0;
		}
	return self;
	}

- reclaim
	{
	// SndKit has no device objects to grab or reset (the legacy
	// re-allocated the NXSoundIn/NXSoundOut here); the method stays
	// so the window notifications still have something harmless to
	// call.
	// don't display here!  That would create a loop.
	return self;
	}

- (void)run
	{
	running=YES;
	//printf ("Run\n");
	if (teNum) 
		{
		[teNum invalidate]; 
		[teNum release];
		}
	
	teNum = [[NSTimer timerWithTimeInterval:refresh 
					 target:self 
				       selector:@selector(VOLUMEMETER_update_meter:) 
				       userInfo:(void*) self repeats:YES] retain];
        [[NSRunLoop currentRunLoop] addTimer:teNum forMode: NSDefaultRunLoopMode];
       					
	[self display];
}

- stop
	{
	running=NO;
	//printf ("Stop\n");
	if (teNum) [teNum invalidate]; [teNum release];;
	teNum=0;
	[self display];
	return self;
	}
	
- (id)initWithCoder:(NSCoder *)aDecoder
	{
	int x;

	[super initWithCoder:aDecoder];
	/*NXReadTypes(stream,"cccccfff",&input,&running,&bezeled,
		&peak_bubble_displayed,&stereo,
		&background_gray,&value_gray,&bubble_gray);*/
	// Commented out to provide new read format:
	[aDecoder decodeValuesOfObjCTypes:"ccccffffi",&input,&bezeled,
		&peak_bubble_displayed,&stereo,
		&background_gray,&value_gray,&bubble_gray,&refresh,
		&refreshes_per_new_peak_bubble];
		
		// from old awake method 
                
		refresh_tally=0;
                for (x=0;x<VOLUMEMETER_MAX_REFRESHES;x++)
                        {refreshes_left[x]=0.0;refreshes_right[x]=0.0;}
                current_max_refresh_left=0;
                current_max_refresh_right=0;

	/* SndKit: no device objects to allocate (see the header note). */



	return self;
	}

- (void)encodeWithCoder:(NSCoder *)aCoder
	{
	[super encodeWithCoder:aCoder];
	/*NXWriteTypes(stream,"cccccfff",&input,&running,&bezeled,
		&peak_bubble_displayed,&stereo,
		&background_gray,&value_gray,&bubble_gray);*/
	// Commented out to provide new write format:
	[aCoder encodeValuesOfObjCTypes:"ccccffffi",&input,&bezeled,
		&peak_bubble_displayed,&stereo,
		&background_gray,&value_gray,&bubble_gray,&refresh,
		&refreshes_per_new_peak_bubble];
}

- (void)dealloc
	{
	if (sound!=nil) [sound release];
	if (delegate!=nil) [delegate release];
	if (teNum) [teNum invalidate]; [teNum release];;
	teNum=0;
	{ [super dealloc]; return; };
	}

- setMono:sender
	{
	return [self setMono];
	}

- setStereo:sender
	{
	return [self setStereo];
	}

- setToInput:sender
	{
	return [self setToInput];
	}

- setToOutput:sender
	{
	return [self setToOutput];
	}

- (void)run:(id)sender
	{
	[self run];
	//return self;
	}

- (void)stop:(id)sender
	{
	[self stop];
	}

- (void)windowDidBecomeKey:(NSNotification *)notification
	{
	//NSWindow *theWindow = [notification object];
    id temp=self;
	//if ([delegate respondsTo:@selector(windowDidBecomeKey:)])
	//	temp=[delegate windowDidBecomeKey:sender];
	if (temp!=NULL) [self reclaim];

	if (temp!=NULL) [self run];
}
	

- (void)windowDidBecomeMain:(NSNotification *)notification
	{
	//NSWindow *theWindow = [notification object];
    id temp=self;
	//if ([delegate respondsTo:@selector(windowDidBecomeMain:)])
	//	temp=[delegate windowDidBecomeMain:sender];
	if (temp!=NULL) [self reclaim];
	if (temp!=NULL) [self run];
}
	

- (void)windowDidDeminiaturize:(NSNotification *)notification
	{
	//NSWindow *theWindow = [notification object];
    id temp=self;
	//if ([delegate respondsTo:@selector(windowDidDeminiaturize:)])
	//	temp=[delegate windowDidDeminiaturize:sender];
	if (temp!=NULL) [self reclaim];
	if (temp!=NULL) [self run];
}
	
	
- (void)windowDidMiniaturize:(NSNotification *)notification
	{
	//NSWindow *theWindow = [notification object];
    id temp=self;
	//if ([delegate respondsTo:@selector(windowDidMiniaturize:)])
	//	temp=[delegate windowDidMiniaturize:sender];
	if (temp!=NULL) [self stop];
}
	
	
- (BOOL)windowShouldClose:(id)sender
	{
	id temp=self;
	//if ([delegate respondsTo:@selector(windowWillClose:)])
	//	temp=[delegate windowWillClose:sender];
	if (temp!=NULL) [self stop];
	return YES;
	}
	
- (void)setSound:(id)this_sound
	{
	if (sound!=nil) [sound release];
	sound=[this_sound retain];
	last_position=0;		// a new sound restarts the peak window
	[self display];
}

- sound
	{
	return sound;
	}
	
- (void)setDelegate:(id)this_delegate
	{
	if (delegate!=nil) [delegate release];
	delegate=[this_delegate retain];
	}
	
- delegate
	{
	return delegate;
	}
	

- (BOOL) isBezeled:sender
	{
	return bezeled;
	}
	
- (BOOL) peakBubbleDisplayed:sender
	{
	return peak_bubble_displayed;
	}
	

- (BOOL) isInput:sender
	{
	return input;
	}
	

- (BOOL) isStereo:sender
	{
	return stereo;
	}
	

- (float) refresh:sender
	{
	return refresh;
	}
	

- (int) refreshesPerPeakBubble:sender
	{
	return refreshes_per_new_peak_bubble;
	}
	
	
// SndKit replacement for the legacy [device getPeakLeft:right:]
// hardware peaks.  SndKit has no device object, and its own
// SndStreamClient peak API (setDetectPeaks:/getPeakLeft:right:)
// is a stub that returns self without touching the values (SndKit's
// own SndMeter calls it, which is why that class documents itself
// as "not ready for operation").  So the peaks are computed from the
// metered sound's data, over the window advanced since the previous
// refresh -- the legacy device peak likewise reported "peak since
// the last call".  The window is the playIndex range of the current
// performance, capped at one second of audio; a sound with no
// performance (in particular the console's zero-buffer recording
// token) has advanced nowhere and reports 0/0, exactly as in unit 1.

- (void) getPeakLeft:(float *) left right:(float *) right
	{
	Snd* snd;
	SndPerformance* performance;
	SndAudioBuffer* buffer;
	void *bytes;
	unsigned long to, from, width, framebytes, n, n_frames;
	int channels;
	SndSampleFormat format;
	float l, r, v0, v1;

	*left = 0.0;
	*right = 0.0;

	snd = nil;
	if ([sound isKindOfClass:[Snd class]]) snd=(Snd*)sound;
	else if ([sound isKindOfClass:[SndView class]])
		snd=(Snd*)[sound soundBeingProcessed];
	if (![snd isKindOfClass:[Snd class]]) return;

	// the current position is the current performance's playIndex,
	// clamped to the sound's length...
	performance=[[snd performances] lastObject];
	to=[snd lengthInSampleFrames];
	if (performance)
		{
		long p=[performance playIndex];
		if (p>0) to=(p>to) ? to : (unsigned long) p;
		}
	if (to<last_position) last_position=0;	// (re)start: window from the beginning
	from=last_position;
	if (to<=from) return;

	// ...capped so a stalled refresh doesn't integrate over the whole
	// sound: at most one second of audio.
	if ([snd samplingRate]>0
		&&to-from>(unsigned long)[snd samplingRate])
		from=to-(unsigned long)[snd samplingRate];

	buffer=[snd audioBufferForSamplesInRange:NSMakeRange((long)from,(long)(to-from))];
	bytes=[buffer bytes];
	if (bytes==NULL) return;
	n_frames=[buffer lengthInSampleFrames];
	channels=[buffer channelCount];
	format=[buffer dataFormat];
	width=SndSampleWidth(format);
	if (width==0||channels<=0||n_frames==0) return;	// a format we don't decode
	framebytes=(unsigned long)channels*width;
	l=0.0;
	r=0.0;
	for (n=0;n<n_frames;n++)
		{
		unsigned char *p=(unsigned char*)bytes+n*framebytes;
		v0=0.0;
		v1=0.0;
		switch (format)
			{
			case SND_FORMAT_FLOAT:
				{
				float *f=(float*)p;
				v0=f[0];
				v1=(channels>1)?f[1]:v0;
				}
				break;
			case SND_FORMAT_LINEAR_16:
				{
				short *s=(short*)p;
				v0=(float)s[0]/32768.0f;
				v1=(channels>1)?(float)s[1]/32768.0f:v0;
				}
				break;
			case SND_FORMAT_LINEAR_8:
				{
				unsigned char *c=p;
				v0=fabs((float)c[0]-128.0f)/128.0f;
				v1=(channels>1)?fabs((float)c[1]-128.0f)/128.0f:v0;
				}
				break;
			case SND_FORMAT_DOUBLE:
				{
				double *d=(double*)p;
				v0=(float)d[0];
				v1=(channels>1)?(float)d[1]:v0;
				}
				break;
			case SND_FORMAT_MULAW_8:
				{
				unsigned char *c=p;
				v0=(float)SndMuLawToLinear(c[0])/32768.0f;
				v1=(channels>1)?(float)SndMuLawToLinear(c[1])/32768.0f:v0;
				}
				break;
			default:
				// compressed formats aren't decoded in the meter.
				break;
			}
		if (v0<0.0) v0=-v0;
		if (v1<0.0) v1=-v1;
		if (v0>l) l=v0;
		if (v1>r) r=v1;
		}
	last_position=to;
	*left=l;
	*right=r;
	return;
	}

// the stereo/mono decision (a hook: ResoundMiscVolumeMeter overrides
// this with Resound's channel-count fallback); the base class is the
// legacy behaviour.

- (void) setChannelsForSound:(id)actual_sound
	{
	if ([((Snd*)actual_sound) channelCount]>1)
		{[self setStereo];}
	else {[self setMono];}
	return;
	}

// The following are delegate methods, just listed here to stop warnings
- meterWillUpdateOnOwn:sender {return NULL;}
- meterWillUpdate:sender {return NULL;}	
- meterDidUpdate:sender	{return NULL;}	
	
- (NSString *)inspectorClassName
        {
	return @"MiscVolumeMeterInspector";
        }
	
@end
