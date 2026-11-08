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
		[currentSound samplingRate]!=SND_RATE_HIGH)
		{
		if (NSRunAlertPanel(@"Echo Chamber",
			@"Convert this sound to mono, 16-bit, 44.1 KHz to perform this operation?",
                      @"Okay",@"Cancel",nil)==NSAlertDefaultReturn)
			{
			if ([currentSoundView convertToFormat: SND_FORMAT_LINEAR_16 
	// we might get a warning here because the sound view doesn't have this
	// function yet
							samplingRate:   SND_RATE_HIGH 
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
	
	soundData16 = (signed short*) [(Sound*)[moduleController currentSound] data];

	SNDSwapSoundToHost
		((void*)soundData16, (void*)soundData16, [currentSound sampleCount], 
			[currentSound channelCount], [currentSound dataFormat]);
		
	datalength =[[moduleController currentSound] dataSize];
	
	delaycount=(int) ([delay floatValue]*44100);
	dropoffvalue= [dropoff floatValue];
	initialvalue= [initial floatValue];
	bigdelay=(int) ([firstDelay floatValue]*44100);
	theratio=[ratio floatValue];
	
	newSound=[[Sound alloc]init];
	[newSound setDataSize:  [currentSound dataSize]		
			dataFormat:   [currentSound dataFormat]
			samplingRate: [currentSound samplingRate]
			channelCount: [currentSound channelCount]
			infoSize:     [currentSound infoSize]];		
			//sets proper data size only for 16-bit mono samples

        soundData2=(signed short int*) [(Sound*)newSound data];

	a=0; b=0;
	addvalue=0;
	for(x=1;x<=datalength/2;x++)
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
	SNDSwapHostToSound
		((void*)soundData2, (void*)soundData2, [newSound sampleCount], 
			[newSound channelCount], [newSound dataFormat]);
	
        [(SoundView*)currentSoundView setSound: newSound];		// TypeCast for OS X server
	[currentSound free];
	[moduleController newSound: newSound for: currentSoundView];




	return self;
}


@end
