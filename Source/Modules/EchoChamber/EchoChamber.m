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
  
#import "EchoChamber.h"
#import "ResoundNibs.h"
#import "ModuleSoundView.h" 

@implementation EchoChamber

- init;
{
	id returnVal=[super init];
	id newNode=[[ModuleMenuNode alloc] initLeafNode:@"Echo Chamber...":self:@selector(begin:)];

	[rootModuleMenuNode addSubmenu:newNode];
		
	return returnVal;
}

- begin:sender;
{
	if (!windowLoaded)
		{
		[ResoundNibs loadNibNamed: @"EchoChamber" owner:self];
		windowLoaded=1;
		}
	[EchoChamberPanel makeKeyAndOrderFront:self];
	return self;
}

- performEcho:sender
{
	signed short* soundData16;
	signed short* soundData2;
	int datalength;
	
	int x;
	int a,b;
	int delaycount;
	int bigdelay;
	short addvalue;
	float dropoffvalue;
	float initialvalue;
	float theratio;
	id currentSound;
	id currentSoundView;
	
	id newSound;
	
	currentSound =[moduleController currentSound];
	currentSoundView =[moduleController currentSoundView];

	if (currentSound==nil)
		{
		NSRunAlertPanel(@"Echo Chamber", 
		@"There is no sound on which I can operate", 
		@"Okay",nil,nil);
		return nil;
		}
	
	if ([currentSound channelCount]>1||
		[currentSound dataFormat]!=SND_FORMAT_LINEAR_16||
		/* 1998: samplingRate]!=SND_RATE_HIGH)  The 1998 SoundKit Snd.h
		   defined SND_RATE_HIGH (44100.0); SndKit has no SND_RATE_*
		   constants, so the value is written out. */
		[currentSound samplingRate]!=44100.0)
		{
		if (NSRunAlertPanel(@"Echo Chamber",
			@"Convert this sound to mono, 16-bit, 44.1 KHz to perform this operation?",
                      @"Okay",@"Cancel",nil)==NSAlertDefaultReturn)
			{
			if ([currentSoundView convertToSampleFormat: SND_FORMAT_LINEAR_16 
	// we might get a warning here because the sound view doesn't have this
	// function yet
							samplingRate:   44100.0 
							channelCount:   1]!= SND_ERR_NONE)
				{
				NSRunAlertPanel(@"Echo Chamber", 
				@"Could not convert sound", 
				@"Okay",nil,nil);
				return nil;
				}
			}
			else return nil;
		}
	
	/* First, we remove anything pastable if we can */
#ifdef PASTE_BUG		
		if ([moduleController isOwner:currentSoundView])
			[moduleController invalidatePasteboard];
#endif			
	[currentSound compactSamples];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];		
	
	soundData16 = (signed short*) [(Snd*)[moduleController currentSound] bytes];

	/* 1998 also swapped the source buffer to host order here; SndKit
	   keeps sample data in host byte order, so the swap is gone (the
	   Zero port made the same change). */

	datalength =[[moduleController currentSound] dataSize];
	
	delaycount=(int) ([delay floatValue]*44100);
	dropoffvalue= [dropoff floatValue];
	initialvalue= [initial floatValue];
	bigdelay=(int) ([firstDelay floatValue]*44100);
	theratio=[ratio floatValue];
	
	/* 1998: newSound=[[Sound alloc] init]; [newSound setDataSize:..
   dataFormat:.. samplingRate:.. channelCount:.. infoSize:..]; (the
   //sets proper data size only for 16-bit mono samples note - the
   pre-check above has left the sound mono/16-bit/44.1k).  SndKit has
   no setDataSize:, so the sound is built directly with the documented
   initializer in the same size, and the info string is carried over
   (the 1998 call reserved the space for it). */
	newSound=[[Snd alloc]
		initWithFormat:   [currentSound dataFormat]
		channelCount: [currentSound channelCount]
		frames:       [currentSound lengthInSampleFrames]
		samplingRate: [currentSound samplingRate]];
	[newSound setInfo: [(Snd*)currentSound info]];

        soundData2=(signed short int*) [(Snd*)newSound bytes];

	a=0; b=0;
	addvalue=0;
	/* 1998: for(x=1; x<=datalength/2; x++)  With dataSize in bytes
	   that runs one sample past the end of both buffers (a latent
	   2-byte heap overflow the 1998 platform's malloc padding
	   absorbed - the extra iteration only ever writes outside the
	   sound's data).  SndKit buffers are exactly sized and modern
	   glibc does not forgive it, so the bound is tightened; the
	   audible samples (1..N-1) are processed identically. */
	for(x=1;x<datalength/2;x++)
		{
		soundData2[x]=soundData16[x];
		if (++a>delaycount)
			{
			addvalue= (short)(
				(float) addvalue*dropoffvalue+
					(float)soundData16[x-delaycount] * initialvalue);
			}
		soundData16[x]+=addvalue;
		if (++b>bigdelay) 
			{
			soundData2[x]+=(short)((float)soundData16[x]*theratio);
			}
		}
	/* (The 1998 code swapped the fresh buffer back to storage order
   here; gone - see above.) */
	
        [(SndView*)currentSoundView setSound: newSound];		// TypeCast for OS X server
	/* 1998: [currentSound free];  GNUstep's NSObject implements -free
	   only to raise an exception (NeXT anachronism), so the 1998 zone
	   free becomes the MRC release: the document's reference is gone
	   after the hand-off below. */
	[currentSound release];
	[moduleController newSound: newSound for: currentSoundView];




	return self;
}


@end
