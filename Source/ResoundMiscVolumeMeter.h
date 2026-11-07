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
unit 1c).  The legacy class duplicated the entire MiscVolumeMeter
drawRect just for its channel-count fallback (a brand-new sound has
0 channels until it is recorded -- a NeXTSTEP bug).  The SndKit port
lifts the channel decision into the MiscVolumeMeter
setChannelsForSound: hook, so this class overrides only that hook.
Everything else (drawing, peaks, status) is inherited from the
ported base class.
 */

#import "MiscVolumeMeter.h"

@interface ResoundMiscVolumeMeter:MiscVolumeMeter
    {
    int default_channel_count;
    }

- init;
- setDefaultChannelCount:(int) this;
- (void) setChannelsForSound:(id)actual_sound;  // A change (was a
                                                // drawRect override)

@end
