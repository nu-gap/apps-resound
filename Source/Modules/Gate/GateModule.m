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
#import "GateModule.h"
#import "ResoundNibs.h"
#import <AppKit/AppKit.h>
#import <SoundKit/SoundKit.h>
#import <Foundation/Foundation.h>
#import <limits.h>
#import <math.h>
#import "ModuleSoundView.h" 

@implementation GateModule

-init
	{
	id returnVal=[super init];
	
	ModuleMenuNode* gateNode=[[ModuleMenuNode alloc] initLeafNode:
	@"Noise Gate...":self:@selector(showNoiseGatePanel:)];

	[rootModuleMenuNode addSubmenu:gateNode];
			
	nib_loaded=0;
	return returnVal;
	}
	
	
	
- showNoiseGatePanel:sender
	{	
	if (!nib_loaded)
		{
       		[ResoundNibs loadNibNamed: @"Gate" owner:self];
		nib_loaded=1;
		}
	[gatePanel makeKeyAndOrderFront:self];
	return self;
	}

#define GATE_STATE_APPLIED 1
#define GATE_STATE_RELEASED 0
	
- gateIt:sender
	{
	Sound* current=[moduleController currentSound];
	
	int gateState=GATE_STATE_RELEASED;
	int gateCount=0;
	
	float threshold=[thresholdField floatValue]/100;
	float secondswait=[secondsWaitField floatValue];
	float secondscut=[secondsCutField floatValue];
	int swait;
	int scut;

	int format=[current dataFormat];
	int channelCount=[current channelCount];
	int sampleCount=[current sampleCount];
	
	void* data;
	unsigned char* data8;
	signed short* data16;
	
	int firstSample, sampleLength;
	
	if (threshold>1) threshold=1;  if (threshold<0) threshold=0;
	if (secondswait<0) secondswait=0;
	if (secondscut<0) secondscut=0;
	
	swait=secondswait*[current samplingRate];
	scut=secondscut*[current samplingRate];
	
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
	data8=(char*)data;
	data16=(signed short*)data;

	SNDSwapSoundToHost
		((void*)data, (void*)data, sampleCount, channelCount, format);

	[[moduleController currentSoundView] 
		getSelection: &firstSample size: &sampleLength];
	if (!sampleLength) {firstSample=0;sampleLength=sampleCount;}	

		
		switch(format)
		{
		case SND_FORMAT_MULAW_8: 
			{
			signed short tempsnd; char* d=(char*)data;
			signed short hi_clip=SHRT_MAX;
			int x; int y;
		
			for (y=0;y<channelCount;y++)
				{
				gateState=GATE_STATE_RELEASED;
				gateCount=0;
	
				for (	x=firstSample*channelCount+y;
						x<(firstSample+sampleLength)*channelCount;
						x+=channelCount)
					{
					tempsnd=SNDiMulaw(d[x]);
					if (gateState==GATE_STATE_RELEASED)
						{
						if (abs(tempsnd)<hi_clip*threshold) gateCount++;
						if (gateCount>swait) 
							{
							gateCount=0; 
							gateState=GATE_STATE_APPLIED; 
							}
						}
					else
						{
						if (abs(tempsnd)>=hi_clip*threshold) 
							{
							gateCount=0; 
							gateState=GATE_STATE_RELEASED;
							}
						else 
							{
							tempsnd*=(gateCount >= scut ? 0 : (1.0-((float)gateCount/(float)scut)));
							gateCount++;
							}
						}
					d[x]=SNDMulaw(tempsnd);
					}
				}
			} break;
		case SND_FORMAT_LINEAR_8: 			
			{
			char tempsnd; char* d=(char*)data;
			char hi_clip=CHAR_MAX;
			int x; int y;
		
			for (y=0;y<channelCount;y++)
				{
				gateState=GATE_STATE_RELEASED;
				gateCount=0;
	
				for (	x=firstSample*channelCount+y;
						x<(firstSample+sampleLength)*channelCount;
						x+=channelCount)
					{
					tempsnd=(d[x]);
					if (gateState==GATE_STATE_RELEASED)
						{
						if (abs(tempsnd)<hi_clip*threshold) gateCount++;
						if (gateCount>swait) 
							{
							gateCount=0; 
							gateState=GATE_STATE_APPLIED; 
							}
						}
					else
						{
						if (abs(tempsnd)>=hi_clip*threshold) 
							{
							gateCount=0; 
							gateState=GATE_STATE_RELEASED;
							}
						else 
							{
							tempsnd*=(gateCount >= scut ? 0 : (1.0-((float)gateCount/(float)scut)));
							gateCount++;
							}
						}
					d[x]=(tempsnd);
					}
				}
			} break;
		case SND_FORMAT_LINEAR_16:  			
			{
			signed short tempsnd; signed short* d=(signed short*)data;
			signed short hi_clip=SHRT_MAX;
			int x; int y;
		
			for (y=0;y<channelCount;y++)
				{
				gateState=GATE_STATE_RELEASED;
				gateCount=0;
	
				for (	x=firstSample*channelCount+y;
						x<(firstSample+sampleLength)*channelCount;
						x+=channelCount)
					{
					tempsnd=(d[x]);
					if (gateState==GATE_STATE_RELEASED)
						{
						if (abs(tempsnd)<hi_clip*threshold) gateCount++;
						if (gateCount>swait) 
							{
							gateCount=0; 
							gateState=GATE_STATE_APPLIED; 
							}
						}
					else
						{
						if (abs(tempsnd)>=hi_clip*threshold) 
							{
							gateCount=0; 
							gateState=GATE_STATE_RELEASED;
							}
						else 
							{
							tempsnd*=(gateCount >= scut ? 0 : (1.0-((float)gateCount/(float)scut)));
							gateCount++;
							}
						}
					d[x]=(tempsnd);
					}
				}
			} break;
		case SND_FORMAT_FLOAT: 			
			{
			float tempsnd; float* d=(float*)data;
			float hi_clip=1.0;
			int x; int y;
		
			for (y=0;y<channelCount;y++)
				{
				gateState=GATE_STATE_RELEASED;
				gateCount=0;
	
				for (	x=firstSample*channelCount+y;
						x<(firstSample+sampleLength)*channelCount;
						x+=channelCount)
					{
					tempsnd=(d[x]);
					if (gateState==GATE_STATE_RELEASED)
						{
						if (abs(tempsnd)<hi_clip*threshold) gateCount++;
						if (gateCount>swait) 
							{
							gateCount=0; 
							gateState=GATE_STATE_APPLIED; 
							}
						}
					else
						{
						if (abs(tempsnd)>=hi_clip*threshold) 
							{
							gateCount=0; 
							gateState=GATE_STATE_RELEASED;
							}
						else 
							{
							tempsnd*=(gateCount >= scut ? 0 : (1.0-((float)gateCount/(float)scut)));
							gateCount++;
							}
						}
					d[x]=(tempsnd);
					}
				}
			} break;
		case SND_FORMAT_DOUBLE: 			
			{
			double tempsnd; double* d=(double*)data;
			double hi_clip=1.0;
			int x; int y;
		
			for (y=0;y<channelCount;y++)
				{
				gateState=GATE_STATE_RELEASED;
				gateCount=0;
	
				for (	x=firstSample*channelCount+y;
						x<(firstSample+sampleLength)*channelCount;
						x+=channelCount)
					{
					tempsnd=(d[x]);
					if (gateState==GATE_STATE_RELEASED)
						{
						if (abs(tempsnd)<hi_clip*threshold) gateCount++;
						if (gateCount>swait) 
							{
							gateCount=0; 
							gateState=GATE_STATE_APPLIED; 
							}
						}
					else
						{
						if (abs(tempsnd)>=hi_clip*threshold) 
							{
							gateCount=0; 
							gateState=GATE_STATE_RELEASED;
							}
						else 
							{
							tempsnd*=(gateCount >= scut ? 0 : (1.0-((float)gateCount/(float)scut)));
							gateCount++;
							}
						}
					d[x]=(tempsnd);
					}
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



