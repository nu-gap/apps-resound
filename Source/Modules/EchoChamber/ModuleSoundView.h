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

/***********************************************************************
 ModuleSoundView.h
 Sean Luke

 ModuleSoundView is a category of extra methods added to Apple/NeXT's
 SoundView object for your convenience. ModuleSoundView.rtf and 
 ModuleSoundView.htmld give documentation on these methods.  See
 Resound's Help system for more information.
************************************************************************/

#import <SndKit/SndKit.h>

@interface SndView(ModuleSoundView)

- (int)	convertToSampleFormat:(int)newFormat
		samplingRate:(double)newRate
		channelCount:(int)newChannelCount;
		
- (NSString*)info;
- setInfo:(NSString*)this;
- (void) setIgnoreShowAndHideCursor:(BOOL)this;
- (void)checkForCurrentDataOnPasteboard;

@end