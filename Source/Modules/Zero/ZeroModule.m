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

/*
ZeroModule
For Resound 3.0
Sean Luke

A simple example module which zeroes out the selected sound, to get you
started using Resound modules.  This code is discussed in Resound's Help
facility, under the section "Building a Resound Module: A Walk-Though".
*/


	#import "ZeroModule.h"
	#import <SndKit/SndKit.h>
	#import <AppKit/AppKit.h>
	#import "ModuleSoundView.h" 

	@implementation ZeroModule

	-init
		{
		id returnVal=[super init];
		
		ModuleMenuNode* zeroNode=[[ModuleMenuNode alloc] 
			initLeafNode:@"Zero":self:@selector(zeroSound:)];
		
		[rootModuleMenuNode addSubmenu: zeroNode];
						
		return returnVal;
		}
		
	- zeroSound:sender
		{
		Snd* current=		[moduleController currentSound];
		SndView* cview=		[moduleController currentSoundView];

		int dataFormat=		[current dataFormat];
		int channelCount=	[current channelCount];
		void* data;
		int x;

		unsigned int firstSample,sampleLength;
		
		[cview getSelection: &firstSample size: &sampleLength];
		
		if (current==nil||!sampleLength)		// no sound
			{
			NSRunAlertPanel(@"No Sound", 
				@"There is no sound with which to perform this operation." , 
				@"Okay",nil,nil);
			return nil;
			}
			
		[moduleController stop];
		[current compactSamples];
                [cview checkForCurrentDataOnPasteboard];

		data=[current bytes];

		// The 1998 code swapped the buffer to host order around the
		// zeroing (SoundKit held its data big-endian).  SndKit holds
		// its data in host order, so the pair is gone; the zeroing
		// itself is endian-independent (0, and 0xFF for mu-law, are
		// the same in every byte order).

		// samples can be stereo or mono.  We need to deal with this fact.
		firstSample*=channelCount;    sampleLength*=channelCount;

		// samples can have many different data formats.  We also need to deal
		// with this fact!
		switch(dataFormat)
			{
			case SND_FORMAT_MULAW_8:
                        	{
				unsigned char mulawzero=SndLinearToMuLaw(0);  // 1998: SNDMulaw(0), "probably 127"; the G.711 code for zero is 0xFF
                        	char* d=(char*) data;
                                for (x=firstSample;x<firstSample+sampleLength;x++) d[x]=mulawzero;
                        	break;
                        	}					
			case SND_FORMAT_LINEAR_8:
				{
				char* d=(char*) data;
				for (x=firstSample;x<firstSample+sampleLength;x++) d[x]=0;
				break;
				}
			case SND_FORMAT_LINEAR_16:
				{
				signed short* d=(signed short*)data;
				for (x=firstSample;x<firstSample+sampleLength;x++) d[x]=0;
				break;
				}
			case SND_FORMAT_FLOAT: 			
				{
				float* d=(float*)data;
				for (x=firstSample;x<firstSample+sampleLength;x++) d[x]=0;
				break;
				}
			case SND_FORMAT_DOUBLE: 			
				{
				double* d=(double*)data;
				for (x=firstSample;x<firstSample+sampleLength;x++) d[x]=0;
				break;
				}
			default:
				NSRunAlertPanel(@"Invalid Format", 
					@"This operation cannot be performed with "
					@"this particular sound format." , 
					@"Okay",NULL,NULL);
				break;
			}
		[moduleController soundTouched];
		return self;
		}	

	@end

