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

This file was migrated from the defunct NeXT SoundKit to SndKit as
part of the GNUstep port (see docs/RESOUND_SNDKIT_PLAN.md, Phase 2,
unit 1c).  The legacy class overrode the entire MiscVolumeMeter
drawRect solely for the channel-count change below; the SndKit port
overrides only the setChannelsForSound: hook (see the header), so
the drawing/peak/status machinery lives in one place (the base
class) and this file is the change itself.
 */

#import "ResoundMiscVolumeMeter.h"

@implementation ResoundMiscVolumeMeter


/*** init
  Initializes the volume meter with a default
  channel count. 
 */

- init
    {
    id returnval=[ super init];
    default_channel_count=1;
    return returnval;
    }




/*** setDefaultChannelCount:
  sets the default channel count.
 */

- setDefaultChannelCount:(int) this
    {
    if (this==1||this==2) default_channel_count=this;
    return self;
    }




/*** setChannelsForSound::
  The one change this class makes to MiscVolumeMeter (the legacy
  version implemented it by duplicating the whole of MiscVolumeMeter's
  drawRect): if the metered sound's channel count cannot be
  ascertained (a brand-new sound has 0 channels until it is recorded
  -- a NeXTSTEP bug), revert to Resound's default channel count.

  The legacy code then always fell through to the plain
  channelCount>1 check, so a 0-channel sound ended up mono
  regardless of the default; calling super after the fallback
  reproduces that exactly.
 */

- (void) setChannelsForSound:(id)actual_sound
    {
    int channels=[((Snd*)actual_sound) channelCount];

    /* Change for Resound */
    if (channels<=0)
        /* unknown sound value, use the set default */
        {
        if (default_channel_count==2) [self setStereo];
        else [self setMono];
        }
    /* End Change */

    [super setChannelsForSound:actual_sound];
    return;
    }

@end
