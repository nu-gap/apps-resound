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

#import <AppKit/AppKit.h>
#import <SndKit/SndKit.h>
#import <Foundation/Foundation.h>
#import "MiscSoundTracker.h"


@interface VolumeController:NSObject
    {
    MiscSoundTracker* mute;
    MiscSoundTracker* monitorMute;
    MiscSoundTracker* lineOutMute;
    MiscSoundTracker* headphonesMute;
    MiscSoundTracker* deemphasis;
    MiscSoundTracker* ramping;
    MiscSoundTracker* left;
    MiscSoundTracker* right;
    MiscSoundTracker* both;
    MiscSoundTracker* monitor;
    
    id muteKnob;
    id monitorMuteKnob;
    id lineOutMuteKnob;
    id headphonesMuteKnob;
    id deemphasisKnob;
    id rampingKnob;
    id leftKnob;
    id rightKnob;
    id bothKnob;
    id monitorKnob;
    
    id volumePanel;
    
    SndStreamMixer* sound_out;
    int		loaded;
    
    
    
    }

- init;
- (void)dealloc;

/* Setting Volume */

- setRight:sender;
- setLeft:sender;
- setMono:sender;
- setMonitor:sender;

/* Setting Filtering */

- setDeemphasis:sender;
- setRamping:sender;

/* Setting Mute */

- setMonitorMute:sender;
- setLineOutMute:sender;
- setHeadphonesMute:sender;
- setMute:sender;

- begin:sender;

@end
