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

  VolumeController.[h|m]
  Sean Luke
  
  VolumeController handles the Volume panel, and manages a bunch of trackers 
  which keep up-to-date with current volume/mute/deemphasis/ramping settings.
  It needs trackers for this stuff because these settings can change with
  keyboard mods that Resound has no control over.  They're pretty efficient
  anyway.

  ****************************************************************************/



#import "VolumeController.h"
#import "ResoundNibs.h"
#import <stdio.h>

@implementation VolumeController


/*** init
  Initializes the volume controller, sets up the sound out stream for the trackers.
*/

- init
    {
    id returnval=[super init];
    sound_out=[[NXSoundOut alloc] init];
    loaded=0;
    return returnval;
    }





/*** begin:
  Loads the nib.  Creates and runs the trackers.  
  This method should be done exactly ONCE.
*/

- begin:sender
    {
    if (!loaded) 
	{
	[ResoundNibs loadNibNamed: @"Volume" owner:self];
	left=[[MiscSoundTracker alloc] init];
	right=[[MiscSoundTracker alloc] init];
	monitorMute=[[MiscSoundTracker alloc] init];
	deemphasis=[[MiscSoundTracker alloc] init];
	ramping=[[MiscSoundTracker alloc] init];
	both=[[MiscSoundTracker alloc] init];
	monitor=[[MiscSoundTracker alloc] init];
	lineOutMute=[[MiscSoundTracker alloc] init];
	headphonesMute=[[MiscSoundTracker alloc] init];
	mute=[[MiscSoundTracker alloc] init];

	[left setTarget: leftKnob];
	[right setTarget: rightKnob];
	[monitorMute setTarget: monitorMuteKnob];
	[deemphasis setTarget: deemphasisKnob];
	[headphonesMute setTarget: headphonesMuteKnob];
	[lineOutMute setTarget: lineOutMuteKnob];
	[mute setTarget: muteKnob];
	[ramping setTarget: rampingKnob];
	[both setTarget: bothKnob];
	[monitor setTarget: monitorKnob];
	
	[left sendLeft];
	[right sendRight];
	[monitorMute sendSpeakerMute];
	[deemphasis sendDeemphasis];
	[ramping sendRamping];
	[both sendMono];
	[mute sendMute];
	[lineOutMute sendLineOutMute];
	[headphonesMute sendHeadphoneMute];
	[monitor sendMonitorAttenuation];

	[[left setRefresh:1.0] run];
	[[right setRefresh:1.0] run];
	[[mute setRefresh:1.0] run];
	[[headphonesMute setRefresh:1.0] run];
	[[monitorMute setRefresh:1.0] run];
	[[lineOutMute setRefresh:1.0] run];
	[[deemphasis setRefresh:1.0] run];
	[[ramping setRefresh:1.0] run];
	[[both setRefresh:1.0] run];
	[[monitor setRefresh:1.0] run];
	loaded=1;
	}
    [volumePanel makeKeyAndOrderFront:self];
    return self;
    }


/*** setFoo methods...
  These set various volume/mute/deemphasis/ramping settings.
*/

- setMute:sender
    {
    [Sound setMute:(BOOL) [muteKnob intValue]];
    return self;
    }


- setRight:sender
    {
    [right setVolumeTo:rightKnob];
    [bothKnob setFloatValue:([rightKnob floatValue]+[leftKnob floatValue])/2];
    return self;
    }

- setLeft:sender
    {
    [left setVolumeTo:leftKnob];
    [bothKnob setFloatValue:([rightKnob floatValue]+[leftKnob floatValue])/2];
    return self;
    }

- setMono:sender
    {
    [both setVolumeTo:bothKnob];
    [rightKnob setFloatValue:[bothKnob floatValue]];
    [leftKnob setFloatValue:[bothKnob floatValue]];
    return self;
    }

- setMonitor:sender
    {
    [monitor setVolumeTo:monitorKnob];
    return self;
    }

- setDeemphasis:sender
    {
    [deemphasis setDeemphasisTo:deemphasisKnob];
    return self;
    }

- setRamping:sender
    {
    [ramping setRampingTo:rampingKnob];
    return self;
    }

- setMonitorMute:sender
    {
    [monitorMute setMuteTo:monitorMuteKnob];
    return self;
    }

- setLineOutMute:sender
    {
    [lineOutMute setMuteTo:lineOutMuteKnob];
    return self;
    }

- setHeadphonesMute:sender
    {
    [headphonesMute setMuteTo:headphonesMuteKnob];
    return self;
    }



/*** dealloc
  Frees the trackers created in begin:, and also frees the sound out stream.
*/

- (void) dealloc
    {
    [left stop];
    [right stop];
    [mute stop];
    [monitorMute stop];
    [lineOutMute stop];
    [headphonesMute stop];
    [deemphasis stop];
    [ramping stop];
    [both stop];
    [monitor stop];

    [left release];
    [right release];
    [monitorMute release];
    [deemphasis release];
    [ramping release];
    [both release];
    [monitor release];
    [lineOutMute release];
    [headphonesMute release];
    [mute release];

    [sound_out release];
    [super dealloc];
    }

@end
