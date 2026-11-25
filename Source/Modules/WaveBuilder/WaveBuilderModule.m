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


#import "WaveBuilderModule.h"
#import "ResoundNibs.h"
#include <stdlib.h>
#import <SndKit/SndKit.h>
#include <math.h>
#import <AppKit/AppKit.h>


#define DOSQUARE 0
#define DOTRIANGLE 1
#define DOBUZZ 2
#define DOSAWTOOTH 3
#define DOPULSE 4


/* For increased speed, I use functions here to figure out my other waveforms.
*/

float pulse (int position, int wavelength)
	{
	if (position%wavelength==0)   	return 1.0;
	if ((position-1)%wavelength==0)	return -1.0;
	return 0.0;
	}
	

float sawtooth (int position, int wavelength)
	{
	if (position%wavelength*2<wavelength)		// positive rise
		{
		return (
			((float)(position%wavelength))*2/wavelength);
		}
	else										// negative rise
		{
		return (
			((float)(position%wavelength-(wavelength/2)))*2/wavelength)-1;
		}
	}
	

float noise (int position, int wavelength)
	{
	/* 1998 fingerprint: RAND_MAX is 2^31-1, which does not fit a
	   float, so the division below converts it to 2^31 and the
	   noise range is scaled by 2^31 rather than the exact
	   2147483647.  The 1998 machine did the same rounding, so the
	   values are the 1998 values - preserved byte-identical, with
	   modern clang pointing the implicit conversion out through
	   -Wimplicit-const-int-float-conversion. */
	return 2*((float)rand())/RAND_MAX-1;
	}


float square (int position, int wavelength)
	{
	if (position%wavelength*2>wavelength)
		{
		return -1.0;
		}
	return 1.0;
	}


float triangle (int position, int wavelength)
	{
	if (position%wavelength*4<wavelength)		// positive rise
		{
		return (
			((float)(position%wavelength))*4/wavelength);
		}
	else if (position%wavelength*2<wavelength)	// positive fall
		{
		return 1-(
			((float)(position%wavelength)-(wavelength/4))*4/wavelength);
		}
	else if ((position%wavelength*4)<wavelength*3)	// negative fall
		{
		return 0-(
			((float)(position%wavelength)-(wavelength/2))*4/wavelength);
		}
	else										// negative rise
		{
		return (
			(((float)(position%wavelength)/(float)(wavelength))-.75)*4)
			-1;
			// okay, don't mock it; it works.
		}
	}




@implementation WaveBuilderModule

- init
{
	id returnval=[super init];
	ModuleMenuNode* submenunode=[[ModuleMenuNode alloc] initNonleafNode:
		@"Generate Sounds"];
	ModuleMenuNode* newnode=[[ModuleMenuNode alloc] initLeafNode:
		@"Sine Harmonics...":self:@selector(loadSinPanel:)];
	ModuleMenuNode* newnode2=[[ModuleMenuNode alloc] initLeafNode:
		@"Other Waves...":self:@selector(loadOthersPanel:)];
	
	[rootModuleMenuNode addSubmenu:  submenunode];
	
	[submenunode addSubmenu:newnode];
	[submenunode addSubmenu: newnode2];
	
	whichToDo=DOSQUARE;
	windowLoaded=0;
	return returnval;
}



- loadSinPanel:sender
{
	if (!windowLoaded)
		{
		[ResoundNibs loadNibNamed: @"WaveBuilder" owner:self];
			// this only works because self is the owner of the bundle
		windowLoaded=1;
		}
	// Rhapsody Interface Builder is stupid: no more
	// way to do pulls-down.
	[sinPopUpButton setPullsDown:YES];
	[sinPopUpButton setTitle:@"Actions..."]; // just in case...
	[sinPanel makeKeyAndOrderFront:self];
	return self;
}




- loadOthersPanel:sender
{
	if (!windowLoaded)
		{
        	[ResoundNibs loadNibNamed: @"WaveBuilder" owner:self];
                	// this only works because self is the owner of the bundle
		windowLoaded=1;
		}
	[othersPanel makeKeyAndOrderFront:self];
	return self;
}



- generateSin:sender
{
    int x;
	int y;
	int length=[sinLength intValue];
	float frequency[16];
	float amplitude[16];
	float phase[16];
	id theNewSound;
	signed short* data;
	int totalnumber;
	int numberdone=0;
	int tempvalue;
	
	if (length)
		{
		/* 1998: theNewSound=[[Sound alloc] init];
		   [theNewSound setDataSize: 2*length dataFormat:
		   SND_FORMAT_LINEAR_16 samplingRate: SND_RATE_HIGH
		   channelCount: 1 infoSize: [theNewSound infoSize]]; (the
		   //sets proper data size only for 16-bit mono samples note -
		   the 2*length bytes of the 1998 call size the buffer for
		   length frames of 16-bit mono, the shape the rest of the
		   method assumes; the infoSize: argument carried the fresh
		   sound's empty info region, and the module never writes an
		   info string, so the SndKit sound's nil info is the same
		   presentation).  SndKit has no setDataSize:, so the sound is
		   built directly with the documented initializer in that
		   shape (the EchoChamber port made the same change). */
		theNewSound=[[Snd alloc]
			initWithFormat:   SND_FORMAT_LINEAR_16
			channelCount: 1
			frames:       length
			samplingRate: SND_RATE_HIGH];
		
		data=(signed short*) [(Snd*)theNewSound bytes];
		
		totalnumber=0;
		for (x=0;x<16;x++)
			{
			frequency[x]=[[sinHarmonics cellAtRow:x column:0] floatValue];
			amplitude[x]=[[sinAmplitudes cellAtRow:x column:0] floatValue];
			phase[x]=[[sinPhases cellAtRow:x column:0] floatValue];
			if (frequency[x]&&amplitude[x]) totalnumber++;
			}
		for (y=0;y<length;y++)
			{								// initializes data
			data[y]=0;
			}
		
		
		
		for (x=0;x<16;x++)
			{
			if (frequency[x]&&amplitude[x]) 
				{
				[percentDoneSin setIntValue: ++numberdone];
				//[percentDoneSin display];
				/* 1998: PSWait() pumped the SoundKit progress
				   machinery between the counter updates.  GNUstep's
				   AppKit (PSOperators.h, pulled in by
				   <AppKit/AppKit.h>) supplies PSWait as a static
				   inline no-op, so the calls below stay
				   byte-identical and do nothing here; the percent
				   counter still drives the panel's progress field. */
				PSWait();
				for (y=0;y<length;y++)
					{
					tempvalue=data[y]+
						(
						32767*amplitude[x]*
						sin((y*frequency[x]*2*3.1415)/44100+phase[x]));
					if (tempvalue>SHRT_MAX) tempvalue=SHRT_MAX;
					if (tempvalue<SHRT_MIN) tempvalue=SHRT_MIN;
					data[y]=(signed short)tempvalue;
					}
				}
			}
			
		/* The 1998 code read the sound's dataFormat/channelCount/
		   sampleCount and swapped the fresh buffer to storage order
		   here, before the hand-off below; the three locals existed
		   only to feed the swap.  SndKit keeps sample data in host
		   byte order, so the swap - and with it the locals - is gone
		   (the Zero port made the same change; the sampleCount read
		   renamed to SndKit's lengthInSampleFrames in the other ports
		   was one of the locals, and goes with it). */
	
		[moduleController brandNewSound: theNewSound];
		}
	return self;
}


- generateOthers:sender
{
	int y;
	int length=[othersLength intValue];
	float frequency=[othersSize floatValue];
	int wavelength;
	float amplitude=32767*[othersAmplitude floatValue];
	id theNewSound;
	signed short* data;
	
	if (length&&frequency&&amplitude)
		{
		wavelength=(int) (1/frequency*44100);
		
		/* 1998: theNewSound=[[Sound alloc] init];
		   [theNewSound setDataSize: 2*length dataFormat:
		   SND_FORMAT_LINEAR_16 samplingRate: SND_RATE_HIGH
		   channelCount: 1 infoSize: [theNewSound infoSize]]; (the
		   same //sets proper data size only for 16-bit mono samples
		   note - the 2*length bytes of the 1998 call size the buffer
		   for length frames of 16-bit mono).  SndKit has no
		   setDataSize:, so the sound is built directly with the
		   documented initializer in that shape, as in generateSin:
		   above. */
		theNewSound=[[Snd alloc]
			initWithFormat:   SND_FORMAT_LINEAR_16
			channelCount: 1
			frames:       length
			samplingRate: SND_RATE_HIGH];
		
		data=(signed short*) [(Snd*)theNewSound bytes];
		
		
		[percentDoneOthers setIntValue:0];
		PSWait();
			for (y=0;y<length;y++)
			{
			/* 1998 fingerprint: for a panel length below 100,
			   length/100 is 0 and this modulo divides by zero - a
			   latent 1998 crash the app would have hit on any short
			   "Other Waves" generation.  Preserved byte-identical,
			   and the contract feeds lengths of 100 or more. */
			if (!(y%(length/100)))
				{
				[percentDoneOthers setIntValue:1+[percentDoneOthers intValue]];
//				[percentDoneOthers display];
				PSWait();

				}	
			switch (whichToDo)
				{
				case DOBUZZ: 
					data[y]=(signed short) (amplitude*(noise(y,wavelength)));
					break;
				case DOTRIANGLE: 
					data[y]=(signed short)(amplitude*(triangle(y,wavelength)));
					break;
				case DOPULSE: 
					data[y]=(signed short) (amplitude*(pulse(y,wavelength)));
					break;
				case DOSQUARE: 
					data[y]=(signed short) (amplitude*(square(y,wavelength)));
					break;
				case DOSAWTOOTH: 
					data[y]=(signed short)(amplitude*(sawtooth(y,wavelength)));
					break;
				}
			}
			
		[percentDoneOthers setIntValue:100];

		/* The 1998 code read the sound's dataFormat/channelCount/
		   sampleCount and swapped the fresh buffer to storage order
		   here, before the hand-off below; SndKit keeps sample data
		   in host byte order, so the swap is gone (see generateSin:
		   above). */
		[moduleController brandNewSound: theNewSound];
		}
	return self;
}

- cosA:sender
{
	float x=440;
	[self clear:self];
	[[sinHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
	[[sinAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
        [[sinTextHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
        [[sinTextAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
        [[sinPhases cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",3.1415/2.0]];
        [[sinTextPhases cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",3.1415/2.0]];
	return self;
}
	
- clear:sender
{
	float x;
	for (x=0;x<16;x++)
		{
		[[sinHarmonics cellAtRow:x column:0] setStringValue:[NSString stringWithFormat:@"%d",0]];
		[[sinAmplitudes cellAtRow:x column:0] setStringValue:[NSString stringWithFormat:@"%d",0]];
		[[sinPhases cellAtRow:x column:0] setStringValue:[NSString stringWithFormat:@"%d",0]];
                [[sinTextHarmonics cellAtRow:x column:0] setStringValue:[NSString stringWithFormat:@"%d",0]];
                [[sinTextAmplitudes cellAtRow:x column:0] setStringValue:[NSString stringWithFormat:@"%d",0]];
                [[sinTextPhases cellAtRow:x column:0] setStringValue:[NSString stringWithFormat:@"%d",0]];
		}
	return self;
}
	

- A:sender
{
	float x=440;
	[self clear:self];
	[[sinHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
	[[sinAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
        [[sinTextHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
        [[sinTextAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
	return self;
}

- As:sender
{
	float x=466.16;
	[self clear:self];
	[[sinHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
	[[sinAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
        [[sinTextHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
        [[sinTextAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
	return self;
}

- B:sender
{
	float x=493.89;
	[self clear:self];
	[[sinHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
	[[sinAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
        [[sinTextHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
        [[sinTextAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
	return self;
}


- C:sender
{
	float x=523.24;
	[self clear:self];
	[[sinHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
	[[sinAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
        [[sinTextHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
        [[sinTextAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
	return self;
}


- Cs:sender
{
	float x=554.36;
	[self clear:self];
	[[sinHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
	[[sinAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
        [[sinTextHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
        [[sinTextAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
	return self;
}


- D:sender
{
	float x=587.32;
	[self clear:self];
	[[sinHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
	[[sinAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
        [[sinTextHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
        [[sinTextAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
	return self;
}


- Ds:sender
{
	float x=622.26;
	[self clear:self];
	[[sinHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
	[[sinAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
        [[sinTextHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
        [[sinTextAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
	return self;
}


- E:sender
{
	float x=659.26;
	[self clear:self];
	[[sinHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
	[[sinAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
        [[sinTextHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
        [[sinTextAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
	return self;
}


- F:sender
{
	float x=698.46;
	[self clear:self];
	[[sinHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
	[[sinAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
        [[sinTextHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
        [[sinTextAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
	return self;
}


- Fs:sender
{
	float x=739.98;
	[self clear:self];
	[[sinHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
	[[sinAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
        [[sinTextHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
        [[sinTextAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
	return self;
}

- G:sender
{
	float x=783.98;
	[self clear:self];
	[[sinHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
	[[sinAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
        [[sinTextHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
        [[sinTextAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
	return self;
}

- Gs:sender
{
	float x=830.62;
	[self clear:self];
	[[sinHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
	[[sinAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
        [[sinTextHarmonics cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%f",x]];
        [[sinTextAmplitudes cellAtRow:0 column:0] setStringValue:[NSString stringWithFormat:@"%d",1]];
	return self;
}


- doNoise:sender
	{
	whichToDo=DOBUZZ;
	return self;
	}
			
- doSquare:sender
	{
	whichToDo=DOSQUARE;
	return self;
	}
		
- doTriangle:sender
	{
	whichToDo=DOTRIANGLE;
	return self;
	}
		
- doSawtooth:sender
	{
	whichToDo=DOSAWTOOTH;
	return self;
	}
		
- doPulse:sender
	{
	whichToDo=DOPULSE;
	return self;
	}


@end
