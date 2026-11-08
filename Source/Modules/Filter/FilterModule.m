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

#import "FilterModule.h"
#import "ResoundNibs.h"
#import <AppKit/AppKit.h>
#import <stdio.h>
#import "ModuleSoundView.h"



/* It appears that there's no OpenStep/Rhapsody equivalent to this very useful
   little function.  That's very sad. -- Sean */
#define NXUserAborted() NO

@implementation FilterModule

- init
{
	id returnVal=[super init];
	ModuleMenuNode* submenunode=[[ModuleMenuNode alloc] initNonleafNode:@"Filter"];
	ModuleMenuNode* newnode=[[ModuleMenuNode alloc] initLeafNode:@"Comb Filter...":self:@selector(LoadFilterPanel:)];
	ModuleMenuNode* newnode2=[[ModuleMenuNode alloc] initLeafNode:@"Echo Filter...":self:@selector(LoadEchoFilterPanel:)];
	
	[rootModuleMenuNode addSubmenu: submenunode];
	
	[submenunode addSubmenu: newnode];
	[submenunode addSubmenu: newnode2];
			
	WindowLoaded=0;
	return returnVal;
}


- LoadFilterPanel:sender
{
	if (!WindowLoaded)
		{
        [ResoundNibs loadNibNamed: @"FilterModule" owner:self];
		WindowLoaded=1;
		}
	[FilterPanel makeKeyAndOrderFront:self];
	return self;
}




- LoadEchoFilterPanel:sender
{
	if (!WindowLoaded)
		{
        [ResoundNibs loadNibNamed: @"FilterModule" owner:self];
		WindowLoaded=1;
		}
	[EchoFilterPanel makeKeyAndOrderFront:self];
	return self;
}



- Apply:sender
{
    Sound* TheCurrentSound;
	SoundView* TheCurrentSoundView;
	
	Sound* TheNewSound;
	signed short* data1;
	signed short* data2;
	int datalength1;
	int datalength2;
	int x,a,b;
	register signed short accumulator;
	float theamplitude[65];
	float sum;
	int minval;
	int maxval;
	int cancelled=0;
	int is_recursive=[recursive intValue];
	
	if ([moduleController currentSound]==nil) 
		{
		NSRunAlertPanel(@"Filter", 
			@"There is no sound on which to perform this operation." , 
			@"Oops",nil,nil);
		return self;
		}
		
	TheCurrentSound =[moduleController currentSound];
	TheCurrentSoundView =[moduleController currentSoundView];
	
	if ([TheCurrentSound channelCount]>1||
		[TheCurrentSound dataFormat]!=SND_FORMAT_LINEAR_16||
		[TheCurrentSound samplingRate]!=SND_RATE_HIGH)
		{
		if (NSRunAlertPanel(@"Filter",
			@"Convert this sound to mono, 16-bit, 44.1 KHz to perform this operation?",
                      @"Okay",@"Cancel",nil)==NSAlertDefaultReturn)
			{
			if ([TheCurrentSoundView convertToFormat: SND_FORMAT_LINEAR_16 
							samplingRate:   SND_RATE_HIGH 
							channelCount:   1]!= SND_ERR_NONE)
				{
				NSRunAlertPanel(@"Filter", 
				@"Could not convert sound", 
				@"Okay",nil,nil);
				return nil;
				}
			}
			else return nil;
		}
		
	[TheCurrentSound compactSamples];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];		
	TheNewSound=[[[Sound alloc]init] autorelease];
	[PercentDone setIntValue: 0];
	PSWait();
	
	data1=(signed short*)[TheCurrentSound data];

	SNDSwapSoundToHost
		((void*)data1, (void*)data1, [TheCurrentSound sampleCount],
			[TheCurrentSound channelCount],
			[TheCurrentSound dataFormat]);

	datalength1=[TheCurrentSound sampleCount];
	
	// Grab amplitude slider information
	
	minval=0;
	maxval=64;
	for (x=0;x<=64;x++) theamplitude[x]=[[Sliders cellAtRow:0 column:x] floatValue];
	for (x=0;theamplitude[x]==0;x++) minval=x;
	for (x=64;theamplitude[x]==0;x--) maxval=x;
	
	sum=0;
	for (x=0;x<=64;x++)
		{
		sum+=[[Sliders cellAtRow:0 column:x] floatValue];
		}

	if (is_recursive)
		{
		[TheNewSound setDataSize:  
			[TheCurrentSound dataSize]
			dataFormat:   [TheCurrentSound dataFormat]
			samplingRate: [TheCurrentSound samplingRate]
			channelCount: [TheCurrentSound channelCount]
			infoSize:     [TheCurrentSound infoSize]];		
			//sets proper data size only for 16-bit mono samples
	
		data2=(signed short*)[TheNewSound data];
		datalength2=[TheNewSound sampleCount];

		// First copy data over to new sound to allow cancellation...
		
		for (x=0;x<datalength1;x++) data2[x]=data1[x];
		
		// Next run comb
		
		for (b=0;b<datalength1;b++)
			{
			accumulator=0;
			for (a=minval;a<=maxval;a++) accumulator+=(signed short)
				(b-32+a<=0||b-32+a>=datalength1 ?
				0 : theamplitude[a]/sum*(float)data2[b-32+a]);
			data2[b]=accumulator;
			if (!(b%1000)) if (NXUserAborted())
				{
				cancelled=1;
				break;
				}
			if (!(b%((int)(datalength1/1000))))
				{
				[PercentDone setIntValue:1+[PercentDone intValue]];
				PSWait();
				}
			}
		if (!cancelled)
			{
		/* First, we remove anything pastable if we can */
#ifdef PASTE_BUG
		if ([moduleController isOwner:TheCurrentSoundView])
			[moduleController invalidatePasteboard];
#endif			
			SNDSwapHostToSound
			((void*)data2, (void*)data2, [TheCurrentSound sampleCount]+64,
				[TheCurrentSound channelCount],
				[TheCurrentSound dataFormat]);
	
			[TheCurrentSoundView setSound: TheNewSound];
			[moduleController newSound: TheNewSound for: TheCurrentSoundView];
			}
		}
	else
		{
		[TheNewSound setDataSize:  
			[TheCurrentSound dataSize]+64*2		// 64 16-byte samples
			dataFormat:   [TheCurrentSound dataFormat]
			samplingRate: [TheCurrentSound samplingRate]
			channelCount: [TheCurrentSound channelCount]
			infoSize:     [TheCurrentSound infoSize]];		
			//sets proper data size only for 16-bit mono samples
	
		data2=(signed short*)[TheNewSound data];
		datalength2=[TheNewSound sampleCount];

		// Run comb
		
		for (b=0;b<datalength2;b++)
			{
			accumulator=0;
			for (a=minval;a<=maxval;a++) accumulator+=(signed short)
					(b-64+a<=0||b-64+a>=datalength1 ?
					0 : theamplitude[a]/sum*(float)data1[b-64+a]);
			data2[b]=accumulator;
			if (!(b%1000)) if (NXUserAborted())
				{
				cancelled=1;
				break;
				}
			}
		if (!cancelled)
			{
		/* First, we remove anything pastable if we can */
#ifdef PASTE_BUG
		if ([moduleController isOwner:TheCurrentSoundView])
			[moduleController invalidatePasteboard];
#endif	
			SNDSwapHostToSound
			((void*)data2, (void*)data2, [TheCurrentSound sampleCount]+64,
				[TheCurrentSound channelCount],
				[TheCurrentSound dataFormat]);
	
			[TheCurrentSoundView setSound: TheNewSound];
			[moduleController newSound: TheNewSound for: TheCurrentSoundView];
			}
		}

	[PercentDone setIntValue: 100];
	PSWait();
	return self;

}



- Zero:sender
{
    return self;
}

- Difference:sender
{
    return self;
}

- Normal:sender
{
    return self;
}

- Echo:sender
{
    return self;
}

- Halve:sender
{
    return self;
}

- Double:sender
{
    return self;
}


- ApplyEcho:sender;
{
    Sound* TheCurrentSound;
	SoundView* TheCurrentSoundView;
	
	Sound* TheNewSound;
	signed short* data1;
	signed short* data2;
	int datalength1;
	int datalength2;
	int x;
	int a;
	int accumulator;
	int theposition[8];					// the number of position sliders
	float theamplitude[8];				// the number of amplitude sliders
	int extraarea=(-[self Min]+[self Max]);
	int min=(-[self Max]);
	int cancelled=0;
	
	if ([moduleController currentSound]==nil) 
		{
		NSRunAlertPanel(@"Filter", 
			@"There is no sound on which to perform this operation." , 
			@"Oops",nil,nil);
		return self;
		}

	TheCurrentSound =[moduleController currentSound];
	TheCurrentSoundView =[moduleController currentSoundView];

	if ([TheCurrentSound channelCount]>1||
		[TheCurrentSound dataFormat]!=SND_FORMAT_LINEAR_16||
		[TheCurrentSound samplingRate]!=SND_RATE_HIGH)
		{
		if (NSRunAlertPanel(@"Filter",
			@"Convert this sound to mono, 16-bit, 44.1 KHz to perform this operation?",
                      @"Okay",@"Cancel",nil)==NSAlertDefaultReturn)
			{
			if ([TheCurrentSoundView convertToFormat: SND_FORMAT_LINEAR_16 
	// we might get a warning here because the sound view doesn't have this
	// function yet
							samplingRate:   SND_RATE_HIGH 
							channelCount:   1]!= SND_ERR_NONE)
				{
				NSRunAlertPanel(@"Filter", 
				@"Could not convert sound", 
				@"Okay",nil,nil);
				return nil;
				}
			}
			else return nil;
		}
		

	[TheCurrentSound compactSamples];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];		

	[EchoPercentDone setIntValue: 0];
	PSWait();
	TheNewSound=[[[Sound alloc] init] autorelease];
	
	[TheNewSound setDataSize:  [TheCurrentSound dataSize]+2*extraarea		
			dataFormat:   [TheCurrentSound dataFormat]
			samplingRate: [TheCurrentSound samplingRate]
			channelCount: [TheCurrentSound channelCount]
			infoSize:     [TheCurrentSound infoSize]];		
			//sets proper data size only for 16-bit mono samples
	
	data1=(signed short*)[TheCurrentSound data];
	data2=(signed short*)[TheNewSound data];
	datalength1=[TheCurrentSound sampleCount];
	datalength2=[TheNewSound sampleCount];
	
	SNDSwapSoundToHost
		((void*)data1, (void*)data1, [TheCurrentSound sampleCount],
			[TheCurrentSound channelCount],
			[TheCurrentSound dataFormat]);

	
	for (x=0;x<=7;x++)
		{
		theposition[x]=-([[Position cellAtRow:x column:0] intValue]);
		theamplitude[x]=[[Amplitude cellAtRow:x column:0] floatValue];
		}
		
		
	for (x=0;x<datalength2;x++)
		{
		accumulator=0;
		for (a=0;a<=7;a++)
			{
			if ((x+min+theposition[a]<=datalength1)&&(x+min+theposition[a]>=0))
				{
				accumulator+=(int)((float)(data1[x+min+theposition[a]])
												*theamplitude[a]);
				}
			}
		data2[x]=accumulator;
		
		if (!(x%(datalength2/100)))
			{
			[EchoPercentDone setIntValue:1+[EchoPercentDone intValue]];
			PSWait();
			}
			
		if (!(x%1000))
			if (NXUserAborted())
				{
				cancelled=1;
				break;
				}
		}

	if (!cancelled)
		{
		/* First, we remove anything pastable if we can */
#ifdef PASTE_BUG		
		if ([moduleController isOwner:TheCurrentSoundView])
			[moduleController invalidatePasteboard];
#endif			
		SNDSwapHostToSound
			((void*)data2, (void*)data2, [TheCurrentSound sampleCount]+extraarea,
				[TheCurrentSound channelCount],
				[TheCurrentSound dataFormat]);
		[TheCurrentSoundView setSound: TheNewSound];
		[moduleController newSound: TheNewSound for: TheCurrentSoundView];
		}
	[EchoPercentDone setIntValue: 100];
	PSWait();
	return self;

}


- MultiEcho:sender;
{
    return self;
}

- (int) Max
{
	int x;
	int n=0;
	for (x=0;x<8;x++)
		{
		if ([[Position cellAtRow:x column:0] intValue]>n)
			{
			n=[[Position cellAtRow:x column:0] intValue];
			}
		}
	return n;
}

- (int) Min
{
	int x;
	int n=0;
	for (x=0;x<8;x++)
		{
		if ([[Position cellAtRow:x column:0] intValue]<n)
			{
			n=[[Position cellAtRow:x column:0] intValue];
			}
		}
	return n;
}


@end
