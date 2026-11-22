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
/* GNUstep's AppKit ships no NXUserAborted either (it was an
   NX private), so the 1998 workaround stays in force: the
   cancellation checks below never fire, as in the shipped
   1998 OpenStep build. */
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
    Snd* TheCurrentSound;
	SndView* TheCurrentSoundView;
	
	Snd* TheNewSound;
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
			if ([TheCurrentSoundView convertToSampleFormat: SND_FORMAT_LINEAR_16 
	// 1998: convertToFormat: SND_RATE_HIGH.  The 1998 SoundKit
	// SoundView proper lacked the method (see the 1998 note in
	// ApplyEcho below); Resound's ModuleSoundView.h category
	// supplied it, and the ported twin of that file declares it
	// on SndView, so the receiver stays the view, as in 1998 and
	// in the EchoChamber port.
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
	/* 1998: TheNewSound=[[[Sound alloc]init] autorelease];
	   The fresh sound is built in the two branches below, where
	   its size differs; the 1998 alloc + setDataSize: pair is
	   replaced there. */
	[PercentDone setIntValue: 0];
	/* 1998: PSWait() pumped the SoundKit progress machinery
	   between the counter updates.  GNUstep's AppKit
	   (PSOperators.h, pulled in by <AppKit/AppKit.h>) supplies
	   PSWait as a static inline no-op, so the calls below stay
	   byte-identical and do nothing here; the percent counter
	   still drives the panel's progress field. */
	PSWait();
	
	data1=(signed short*)[TheCurrentSound bytes];

	/* 1998 also swapped the buffer to host order here; SndKit
	   keeps sample data in host byte order, so the swap is gone
	   (the Zero port made the same change). */

	/* 1998: [TheCurrentSound sampleCount];  renamed to SndKit's
	   lengthInSampleFrames (the Mix port made the same change). */
	datalength1=[TheCurrentSound lengthInSampleFrames];
	
	// Grab amplitude slider information
	
	minval=0;
	maxval=64;
	for (x=0;x<=64;x++) theamplitude[x]=[[Sliders cellAtRow:0 column:x] floatValue];
	/* 1998 fingerprint: the two zero-scans run while the cell is
	   zero, so an all-zero curve (all 65 sliders at 0, reachable
	   from the panel) walks off both ends of the 65-element stack
	   array and leaves sum at 0, which the comb loop below
	   divides by.  Preserved byte-identical; the contract's curve
	   keeps the zeros as leading and trailing taps only. */
	for (x=0;theamplitude[x]==0;x++) minval=x;
	for (x=64;theamplitude[x]==0;x--) maxval=x;
	
	sum=0;
	for (x=0;x<=64;x++)
		{
		sum+=[[Sliders cellAtRow:0 column:x] floatValue];
		}

	if (is_recursive)
		{
		/* 1998: [TheNewSound setDataSize: [TheCurrentSound dataSize]
		   dataFormat:.. samplingRate:.. channelCount:.. infoSize:..];
		   (the //sets proper data size only for 16-bit mono
		   samples note - the pre-check above has left the sound
		   mono/16-bit/44.1k).  SndKit has no setDataSize:, so the
		   sound is built directly with the documented initializer
		   in the same size, and the info string is carried over
		   (the 1998 call only reserved the space for it); the
		   early empty alloc is superseded by this.  The
		   EchoChamber port made the same change. */
		TheNewSound=[[[Snd alloc]
			initWithFormat:   [TheCurrentSound dataFormat]
			channelCount: [TheCurrentSound channelCount]
			frames:       [TheCurrentSound lengthInSampleFrames]
			samplingRate: [TheCurrentSound samplingRate]] autorelease];
		[TheNewSound setInfo: [TheCurrentSound info]];
	
		data2=(signed short*)[TheNewSound bytes];
		datalength2=[TheNewSound lengthInSampleFrames];

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
			/* 1998 fingerprint: for a sound with fewer than 1000
			   samples, datalength1/1000 is 0 and this modulo
			   divides by zero; preserved byte-identical, and the
			   contract feeds it sounds of 1000 samples or more. */
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
			/* (The 1998 code swapped the buffer back to storage order
			   here; gone - see above.) */
	
			[TheCurrentSoundView setSound: TheNewSound];
			[moduleController newSound: TheNewSound for: TheCurrentSoundView];
			}
		}
	else
		{
		/* 1998: [TheNewSound setDataSize: [TheCurrentSound dataSize]
		   +64*2  // 64 16-byte samples ...]  - for the guaranteed
		   mono/16-bit sound the 1998 +64*2 bytes is +64 frames.
		   SndKit has no setDataSize:, so the sound is built
		   directly with the documented initializer in that size,
		   and the info string is carried over (as above); the
		   EchoChamber port made the same change. */
		TheNewSound=[[[Snd alloc]
			initWithFormat:   [TheCurrentSound dataFormat]
			channelCount: [TheCurrentSound channelCount]
			frames:       [TheCurrentSound lengthInSampleFrames]+64
			samplingRate: [TheCurrentSound samplingRate]] autorelease];
		[TheNewSound setInfo: [TheCurrentSound info]];
	
		data2=(signed short*)[TheNewSound bytes];
		datalength2=[TheNewSound lengthInSampleFrames];

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
			/* (The 1998 code swapped the buffer back to storage order
			   here; gone - see above.) */
	
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
    Snd* TheCurrentSound;
	SndView* TheCurrentSoundView;
	
	Snd* TheNewSound;
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
			if ([TheCurrentSoundView convertToSampleFormat: SND_FORMAT_LINEAR_16 
	// we might get a warning here because the sound view doesn't have this
	// function yet
	// (1998: that is the SoundKit SoundView proper - Resound's
	// ModuleSoundView.h category supplied the method; the ported
	// twin of the file declares it on SndView, so the call
	// compiles and the app's MiscSoundView implements it.)
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
	/* 1998: TheNewSound=[[Sound alloc] init]; [TheNewSound
	   setDataSize: [TheCurrentSound dataSize]+2*extraarea ...];
	   (the //sets proper data size only for 16-bit mono
	   samples note - the pre-check above has left the sound
	   mono/16-bit/44.1k).  SndKit has no setDataSize:, so the
	   sound is built directly with the documented initializer in
	   that size, and the info string is carried over; the
	   EchoChamber port made the same change. */
	TheNewSound=[[[Snd alloc]
		initWithFormat:   [TheCurrentSound dataFormat]
		channelCount: [TheCurrentSound channelCount]
		frames:       [TheCurrentSound lengthInSampleFrames]+2*extraarea
		samplingRate: [TheCurrentSound samplingRate]] autorelease];
	[TheNewSound setInfo: [TheCurrentSound info]];
	
	data1=(signed short*)[TheCurrentSound bytes];
	data2=(signed short*)[TheNewSound bytes];
	datalength1=[TheCurrentSound lengthInSampleFrames];
	datalength2=[TheNewSound lengthInSampleFrames];
	
	/* 1998 also swapped the buffer to host order here; SndKit
	   keeps sample data in host byte order, so the swap is gone
	   (see above). */

	
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
		
		/* 1998 fingerprint: for an output of fewer than 100
		   samples, datalength2/100 is 0 and this modulo divides
		   by zero; preserved byte-identical, and the contract
		   feeds it outputs of 100 samples or more. */
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
		/* (The 1998 code swapped the buffer back to storage order
		   here; gone - see above.) */
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

/* 1998 fingerprint: both of these accumulate from n=0 with a
   strict inequality, so Max can never be negative and Min can
   never be positive - with an all-positive position matrix,
   Min returns 0 instead of the smallest position, and the
   buffer sizing in ApplyEcho (extraarea = -Min+Max,
   min = -Max) follows the clamp.  Preserved byte-identical;
   the contract mirrors it. */
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
