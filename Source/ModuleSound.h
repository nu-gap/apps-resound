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
 ModuleSound.h
 Sean Luke

 ModuleSound is a category of extra methods added to Apple/NeXT's Sound
 object for your convenience. ModuleSound.rtf and ModuleSound.htmld give
 documentation on these methods.  See Resound's Help system for more
 information.
************************************************************************/

#import <SndKit/SndKit.h>

@interface Snd(ModuleSound)

- (int)sampleSize;
- (int)sampleSizePerChannel;
+ (int) performFFTFromSoundData:(char*)data:(int)start_sample:
	(int)sample_length:(int)dataFormat:(int)numChannels
		toFFTData:(float*)fft_data:(int)fft_length;
+ (int) performIFFTToSoundData:(char*)data:(int)start_sample:
	(int)sample_length:(int)dataFormat:(int)numChannels
		fromFFTData:(float*)fft_data:(int)fft_length;
+ (int) nextPositivePowerOfTwo:(int)value;

@end