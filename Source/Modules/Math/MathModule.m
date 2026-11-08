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


/* This complex macro lets us shorten this file somewhat.  
   Hey, you can cut-and-paste if ya like.
   This is a macro because of the myriad of sound types (yuck).
   
   For each element in the sound array, the macro assigns the element
   to tempsnd.  It then performs tempsnd=(<operation>), then assigns 
   tempsnd to the element to store it back.  <operation> should be some 
   function of tempsnd, hi_clip, and low_clip (for example, inverting the 
   sound has operation being (-tempsnd)). hi_clip is the maximum possible
   amplitude value and low_clip is the minimum possible (negative) 
   amplitude value.
   
   The macro needs to be able to freely create the variables 
   d, x, hi_clip, low_clip, and tempsnd.
   
   It also needs pre-set the integers 
   		firstSample (the sample in the sound data to start at),
		sampleLength (how many samples to do the operation over)
   		channelCount (the number of channels in the sound)
   		format (the sound data format)
	Finally, it needs the sound data to be stored as a char* in the variable
		data

 */




#define MATH_INDEPENDENT(operation)\
	switch(format)\
		{\
		case SND_FORMAT_MULAW_8: \
			{\
			signed short tempsnd; int x; char* d=(char*)data;\
			signed short hi_clip=SHRT_MAX; signed short low_clip=SHRT_MIN;\
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)\
				{ tempsnd=SNDiMulaw(d[x]); tempsnd=(signed short)(operation); d[x]=SNDMulaw(tempsnd); }\
			tempsnd=hi_clip; tempsnd=low_clip; } break;\
		case SND_FORMAT_LINEAR_8: 			\
			{\
			char tempsnd; int x; char* d=(char*)data;\
			char hi_clip=CHAR_MAX; char low_clip=CHAR_MIN;\
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)\
				{ tempsnd=d[x]; tempsnd=(char)(operation); d[x]=tempsnd; }\
			tempsnd=hi_clip; tempsnd=low_clip; } break;\
		case SND_FORMAT_LINEAR_16:  			\
			{\
			signed short tempsnd; int x; signed short* d=(signed short*)data;\
			signed short hi_clip=SHRT_MAX; signed short low_clip=SHRT_MIN;\
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)\
				{ tempsnd=d[x]; tempsnd=(signed short)(operation); d[x]=tempsnd;}\
			tempsnd=hi_clip; tempsnd=low_clip; } break;\
		case SND_FORMAT_FLOAT: 			\
			{\
			float tempsnd; int x; float* d=(float*)data;\
			float hi_clip=1.0; float low_clip=-(1.0);\
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)\
				{ tempsnd=d[x]; tempsnd=(float)(operation); d[x]=tempsnd;}\
			tempsnd=hi_clip; tempsnd=low_clip; } break;\
		case SND_FORMAT_DOUBLE: 			\
			{\
			double tempsnd; int x; double* d=(double*)data;\
			double hi_clip=1.0; double low_clip=-(1.0);\
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)\
				{ tempsnd=d[x]; tempsnd=(double)(operation); d[x]=tempsnd;}\
			tempsnd=hi_clip; tempsnd=low_clip; } break;\
		default: \
			NSRunAlertPanel(@"Invalid Format", \
				@"This operation cannot be performed with this particular sound format." , \
				@"Okay",nil,nil);\
		}
	







#import "MathModule.h"
#import "ResoundNibs.h"
#import <AppKit/AppKit.h>
#import <SoundKit/SoundKit.h>
#import <limits.h>
#import <math.h>
#import "ModuleSoundView.h" 

@implementation MathModule

-init
	{
	id returnVal=[super init];
	
	ModuleMenuNode* newNode=[[ModuleMenuNode alloc] initNonleafNode:
		@"Amplitude"];
 	ModuleMenuNode* volumeNode=[[ModuleMenuNode alloc] initLeafNode:
		@"Change Amplitude...":self:@selector(showMultiplyPanel:)];
	ModuleMenuNode* shiftNode=[[ModuleMenuNode alloc] initLeafNode:
		@"Vertical Shift...":self:@selector(showShiftPanel:)];
	ModuleMenuNode* absNode=[[ModuleMenuNode alloc] initLeafNode:
		@"AbsoluteValue":self:@selector(absIt:)];
	ModuleMenuNode* invertNode=[[ModuleMenuNode alloc] initLeafNode:
		@"Invert":self:@selector(invertIt:)];
	ModuleMenuNode* reverseNode=[[ModuleMenuNode alloc] initLeafNode:
		@"Reverse":self:@selector(reverseIt:)];
	
	[rootModuleMenuNode addSubmenu: newNode];
	[rootModuleMenuNode addSubmenu: reverseNode];
	
	[newNode addSubmenu:volumeNode];
	[newNode addSubmenu:shiftNode];
	[newNode addSubmenu:invertNode];
	[newNode addSubmenu:absNode];
	
	nib_loaded=0;
	return returnVal;
	}
	
	
	
- showMultiplyPanel:sender
	{
	if (!nib_loaded)
		{
		[ResoundNibs loadNibNamed: @"Math" owner:self]; // this only works because self is the main class of the bundle!
		nib_loaded=1;
		}
	[multiplyPanel makeKeyAndOrderFront:self];
	return self;
	}

- showShiftPanel:sender
	{
	if (!nib_loaded)
		{
        	[ResoundNibs loadNibNamed: @"Math" owner:self]; // this only works because self is the main class of the bundle!
		nib_loaded=1;
		}
	[shiftPanel makeKeyAndOrderFront:self];
	return self;
	}

	
	
	
- absIt:sender
	{
	Sound* current=[moduleController currentSound];

	int format=[current dataFormat];
	int channelCount=[current channelCount];
	int sampleCount=[current sampleCount];
	
	void* data;
	
	int firstSample, sampleLength;
	
	if (current==nil)
		{
		NSRunAlertPanel(@"No Sound", 
			@"There is no sound with which to perform this operation." , 
			@"Okay",nil,nil);
		return self;
		}

	[moduleController stop];
	[current compactSamples];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];
		
	data=(void*)[current data];

	SNDSwapSoundToHost
		((void*)data, (void*)data, sampleCount, channelCount, format);

	[[moduleController currentSoundView] 
		getSelection: &firstSample size: &sampleLength];
	if (!sampleLength) {firstSample=0;sampleLength=sampleCount;}	
		
	MATH_INDEPENDENT(fabs((double)tempsnd))	
	
	SNDSwapHostToSound
		((void*)data, (void*)data, sampleCount, channelCount, format);
	[moduleController soundChanged];
	return self;
	}
	

- invertIt:sender
	{
	Sound* current=[moduleController currentSound];
	
	int format=[current dataFormat];
	int channelCount=[current channelCount];
	int sampleCount=[current sampleCount];
	
	void* data;

	int firstSample, sampleLength;
		
	if (current==nil)
		{
		NSRunAlertPanel(@"No Sound", 
			@"There is no sound with which to perform this operation." , 
			@"Okay",nil,nil);
		return self;
		}

	[moduleController stop];
	[current compactSamples];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];

	data=(void*)[current data];

	SNDSwapSoundToHost
		((void*)data, (void*)data, sampleCount, channelCount, format);

	[[moduleController currentSoundView] 
		getSelection: &firstSample size: &sampleLength];
	if (!sampleLength) {firstSample=0;sampleLength=sampleCount;}	
		
	MATH_INDEPENDENT((-tempsnd))	
	
	SNDSwapHostToSound
		((void*)data, (void*)data, sampleCount, channelCount, format);
	[moduleController soundChanged];
	return self;
	}
	

- multiplyIt:sender
	{
	Sound* current=[moduleController currentSound];
	float slider=[percentChangeField floatValue];
	
	int format=[current dataFormat];
	int channelCount=[current channelCount];
	int sampleCount=[current sampleCount];
	
	void* data;
	
	int firstSample, sampleLength;
	
	if (current==nil)
		{
		NSRunAlertPanel(@"No Sound", 
			@"There is no sound with which to perform this operation." , 
			@"Okay",nil,nil);
		return self;
		}

	[moduleController stop];
	[current compactSamples];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];

	data=(void*)[current data];

	SNDSwapSoundToHost
		((void*)data, (void*)data, sampleCount, channelCount, format);

	[[moduleController currentSoundView] 
		getSelection: &firstSample size: &sampleLength];
	if (!sampleLength) {firstSample=0;sampleLength=sampleCount;}	
			
	MATH_INDEPENDENT(tempsnd*slider/100 > hi_clip ? hi_clip : (tempsnd*slider/100 < low_clip ? low_clip : tempsnd*slider/100))
	
	SNDSwapHostToSound
		((void*)data, (void*)data, sampleCount, channelCount, format);
	[moduleController soundChanged];
	return self;
	}
			

- shiftIt:sender
	{
	Sound* current=[moduleController currentSound];
	float slider=[shiftSliderValue floatValue];
	
	int format=[current dataFormat];
	int channelCount=[current channelCount];
	int sampleCount=[current sampleCount];
	
	void* data;
	
	int firstSample, sampleLength;
	
	if (current==nil)
		{
		NSRunAlertPanel(@"No Sound", 
			@"There is no sound with which to perform this operation." , 
			@"Okay",nil,nil);
		return self;
		}

	[moduleController stop];
	[current compactSamples];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];
		
	data=(void*)[current data];

	SNDSwapSoundToHost
		((void*)data, (void*)data, sampleCount, channelCount, format);

	[[moduleController currentSoundView] 
		getSelection: &firstSample size: &sampleLength];
	if (!sampleLength) {firstSample=0;sampleLength=sampleCount;}	
		
	MATH_INDEPENDENT(tempsnd+(slider*hi_clip) > hi_clip ? hi_clip : (tempsnd+(slider*hi_clip) < low_clip ? low_clip : tempsnd+(slider*hi_clip)))

	SNDSwapHostToSound
		((void*)data, (void*)data, sampleCount, channelCount, format);
	[moduleController soundChanged];
	return self;
	}






			



- halve:sender
	{
	[percentChangeScroller setIntValue:50];
	[percentChangeField setIntValue:50];	
	return self;
	}

- double:sender;
	{
	[percentChangeScroller setIntValue:200];
	[percentChangeField setIntValue:200];	
	return self;
	}

- maximize:sender
	{
	Sound* current=[moduleController currentSound];
	
	int format=[current dataFormat];
	int channelCount=[current channelCount];
	int sampleCount=[current sampleCount];
	
	void* data;
	
	int firstSample, sampleLength;
	
	if (current==nil)
		{
		NSRunAlertPanel(@"No Sound", 
			@"There is no sound with which to perform this operation." , 
			@"Okay",nil,nil);
		return self;
		}

	[moduleController stop];
	[current compactSamples];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];
		
	data=(void*)[current data];

	SNDSwapSoundToHost
		((void*)data, (void*)data, sampleCount, channelCount, format);

	[[moduleController currentSoundView] 
		getSelection: &firstSample size: &sampleLength];
	if (!sampleLength) {firstSample=0;sampleLength=sampleCount;}	
			
	switch(format)
		{
		case SND_FORMAT_MULAW_8: 
			{
			signed short tempsnd; int x; char* d=(char*)data;
			signed short hi_clip=SHRT_MAX; signed short max=0; 
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ 
				tempsnd=SNDiMulaw(d[x]); 	
				if (max<abs(tempsnd)) max=(float)abs(tempsnd); 
				/* d[x]=SNDMulaw(tempsnd); */ 
				}
			[percentChangeField setFloatValue: ((float)hi_clip)/((float)max)*100.0];
			[percentChangeScroller setFloatValue:[percentChangeField floatValue]];
			} break;
		case SND_FORMAT_LINEAR_8: 			
			{
			int x; char* d=(char*)data;
			char hi_clip=CHAR_MAX; char max=0;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ if (max<abs(d[x])) max=(float)abs(d[x]);  }
			[percentChangeField setFloatValue: ((float)hi_clip)/((float)max)*100.0];
			[percentChangeScroller setFloatValue:[percentChangeField floatValue]];
			} break;
		case SND_FORMAT_LINEAR_16:  			
			{
			int x; signed short* d=(signed short*)data;
			signed short hi_clip=SHRT_MAX; signed short max=0;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ if (max<abs(d[x])) max=(float)abs(d[x]);  }
			[percentChangeField setFloatValue: ((float)hi_clip)/((float)max)*100.0];
			[percentChangeScroller setFloatValue:[percentChangeField floatValue]];
			} break;
		case SND_FORMAT_FLOAT: 			
			{
			int x; float* d=(float*)data;
			float hi_clip=1.0; float max=0;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ if (max<fabs(d[x])) max=fabs(d[x]);  }
			[percentChangeField setFloatValue: ((float)hi_clip)/((float)max)*100.0];
			[percentChangeScroller setFloatValue:[percentChangeField floatValue]];
			} break;
		case SND_FORMAT_DOUBLE: 			
			{
			int x; double* d=(double*)data;
			double hi_clip=1.0; double max=0;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ if (max<fabs(d[x])) max=fabs(d[x]);   }
			[percentChangeField setFloatValue: ((float)hi_clip)/((float)max)*100.0];
			[percentChangeScroller setFloatValue:[percentChangeField floatValue]];
			} break;
		default: 
			NSRunAlertPanel(@"Invalid Format", 
				@"This operation cannot be performed with this particular sound format." , 
				@"Okay",nil,nil);
		}

	
	SNDSwapHostToSound
		((void*)data, (void*)data, sampleCount, channelCount, format);
	return self;
	}	
	



- reverseIt:sender
	{
	Sound* current=[moduleController currentSound];
	
	int format=[current dataFormat];
	int channelCount=[current channelCount];
	int sampleCount=[current sampleCount];

	void* data;
	
	int firstSample, sampleLength;
	
	if (current==nil)
		{
		NSRunAlertPanel(@"No Sound", 
			@"There is no sound with which to perform this operation." , 
			@"Okay",nil,nil);
		return self;
		}

	[moduleController stop];
	[current compactSamples];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];

	data=(void*)[current data];

	SNDSwapSoundToHost
		((void*)data, (void*)data, sampleCount, channelCount, format);
	
	[[moduleController currentSoundView] 
		getSelection: &firstSample size: &sampleLength];
	if (!sampleLength) {firstSample=0;sampleLength=sampleCount;}	
		

	switch(format)
		{
		case SND_FORMAT_MULAW_8: 
			{
			int x; char* d=(char*)data;
			char trader=0;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength/2)*channelCount;x++)
				{
				trader=d[x];
				d[x]=d[(firstSample+sampleLength)*channelCount-x-1
					+firstSample*channelCount];
				d[(firstSample+sampleLength)*channelCount-x-1
					+firstSample*channelCount]=trader;
				}
			if (channelCount==2)								// stereo
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x+=2)
				{
				trader=d[x];
				d[x]=d[x+1];
				d[x+1]=trader;
				}
			} break;
		case SND_FORMAT_LINEAR_8: 			
			{
			int x; char* d=(char*)data;
			char trader=0;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength/2)*channelCount;x++)
				{
				trader=d[x];
				d[x]=d[(firstSample+sampleLength)*channelCount-x-1
					+firstSample*channelCount];
				d[(firstSample+sampleLength)*channelCount-x-1
					+firstSample*channelCount]=trader;
				}
			if (channelCount==2)								// stereo
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x+=2)
				{
				trader=d[x];
				d[x]=d[x+1];
				d[x+1]=trader;
				}
			} break;
		case SND_FORMAT_LINEAR_16:  			
			{
			int x; signed short* d=(signed short*)data;
			signed short trader=0;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength/2)*channelCount;x++)
				{
				trader=d[x];
				d[x]=d[(firstSample+sampleLength)*channelCount-x-1
					+firstSample*channelCount];
				d[(firstSample+sampleLength)*channelCount-x-1
					+firstSample*channelCount]=trader;
				}
			if (channelCount==2)								// stereo
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x+=2)
				{
				trader=d[x];
				d[x]=d[x+1];
				d[x+1]=trader;
				}
			} break;
		case SND_FORMAT_FLOAT: 			
			{
			int x; float* d=(float*)data;
			float trader=0;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength/2)*channelCount;x++)
				{
				trader=d[x];
				d[x]=d[(firstSample+sampleLength)*channelCount-x-1
					+firstSample*channelCount];
				d[(firstSample+sampleLength)*channelCount-x-1
					+firstSample*channelCount]=trader;
				}
			if (channelCount==2)								// stereo
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x+=2)
				{
				trader=d[x];
				d[x]=d[x+1];
				d[x+1]=trader;
				}
			} break;
		case SND_FORMAT_DOUBLE: 			
			{
			int x; double* d=(double*)data;
			double trader=0;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength/2)*channelCount;x++)
				{
				trader=d[x];
				d[x]=d[(firstSample+sampleLength)*channelCount-x-1
					+firstSample*channelCount];
				d[(firstSample+sampleLength)*channelCount-x-1
					+firstSample*channelCount]=trader;
				}
			if (channelCount==2)								// stereo
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x+=2)
				{
				trader=d[x];
				d[x]=d[x+1];
				d[x+1]=trader;
				}
			} break;
		default: 
			NSRunAlertPanel(@"Invalid Format", 
				@"This operation cannot be performed with this particular sound format." , 
				@"Okay",nil,nil);
		}

	SNDSwapHostToSound
		((void*)data, (void*)data, sampleCount, channelCount, format);
	[moduleController soundChanged];
	return self;
	}
	


@end



