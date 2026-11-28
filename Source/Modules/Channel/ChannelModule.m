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
#import "ChannelModule.h"
#import <AppKit/AppKit.h>
#import <SndKit/SndKit.h>
#import <limits.h>
#import <math.h>
#import "ModuleSoundView.h" 



@implementation ChannelModule

-init
	{
	id returnVal=[super init];
	
	ModuleMenuNode* newNode=[[ModuleMenuNode alloc] initNonleafNode:@"Channel"];
 	ModuleMenuNode* addLeft=[[ModuleMenuNode alloc] initLeafNode:
		@"Add a Blank Left Channel":self:@selector(addLeft:)];
	ModuleMenuNode* addRight=[[ModuleMenuNode alloc] initLeafNode:
		@"Add a Blank Right Channel":self:@selector(addRight:)];
	ModuleMenuNode* stripLeft=[[ModuleMenuNode alloc] initLeafNode:
		@"Delete the Left Channel":self:@selector(stripLeft:)];
	ModuleMenuNode* stripRight=[[ModuleMenuNode alloc] initLeafNode:
		@"Delete the Right Channel":self:@selector(stripRight:)];
	ModuleMenuNode* swap=[[ModuleMenuNode alloc] initLeafNode:
		@"Swap Channels":self:@selector(swap:)];
	
	[rootModuleMenuNode addSubmenu: newNode];
	
	[newNode addSubmenu:addLeft];
	[newNode addSubmenu:addRight];
	[newNode addSubmenu:stripLeft];
	[newNode addSubmenu:stripRight];
	[newNode addSubmenu:swap];
			
	return returnVal;
	}
	
	
-swap:sender
	{
	/* Swap channels */
	Snd* current=[moduleController currentSound];
	
	int format=[current dataFormat];
	int channelCount=[current channelCount];
	int sampleCount=[current lengthInSampleFrames];
	char trader;

	void* data;
	
	
	unsigned int firstSample, sampleLength;
	
	if (current==NULL)
		{
		NSRunAlertPanel(@"No Sound", 
			@"There is no sound with which to perform this operation." , 
			@"Okay",NULL,NULL);
		return self;
		}

	if ([current channelCount]!=2)
		{
		NSRunAlertPanel(@"Incorrect Number of Channels", 
			@"This sound is not stereo." , 
			@"Okay",NULL,NULL);
		return self;
		}

	[moduleController stop];
	[current compactSamples];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];		

	data=(void*)[current bytes];

	/* 1998: SNDSwapSoundToHost
	   ((void*)data, (void*)data, sampleCount, channelCount, format);
	   - SndKit keeps sample data in host byte order, so the swap pair
	   around each DSP is gone (the Zero change; the Mix, Math and the
	   other ports documented the same pair). */

	[[moduleController currentSoundView] 
		getSelection: &firstSample size: &sampleLength];
	if (!sampleLength) {firstSample=0;sampleLength=sampleCount;}	

	switch(format)
		{
		case SND_FORMAT_MULAW_8: 
			{
			int x; char* d=(char*)data;

			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ trader=d[x];d[x]=d[x+1];d[x+1]=trader; }
			} break;
		case SND_FORMAT_LINEAR_8: 			
			{
			char tempsnd; int x; char* d=(char*)data; 
			char hi_clip=CHAR_MAX; char low_clip=CHAR_MIN;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ trader=d[x];d[x]=d[x+1];d[x+1]=trader; }
			tempsnd=hi_clip; tempsnd=low_clip;   } break;
		case SND_FORMAT_LINEAR_16:  			
			{
			signed short tempsnd; int x; signed short* d=(signed short*)data; 
			signed short hi_clip=SHRT_MAX; signed short low_clip=SHRT_MIN;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ trader=d[x];d[x]=d[x+1];d[x+1]=trader; }
			tempsnd=hi_clip; tempsnd=low_clip;   } break;
		case SND_FORMAT_FLOAT: 			
			{
			float tempsnd; int x; float* d=(float*)data; 
			float hi_clip=1.0; float low_clip=-(1.0);
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ trader=d[x];d[x]=d[x+1];d[x+1]=trader; }
			tempsnd=hi_clip; tempsnd=low_clip;   } break;
		case SND_FORMAT_DOUBLE: 			
			{
			double tempsnd; int x; double* d=(double*)data;
			double hi_clip=1.0; double low_clip=-(1.0);
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ trader=d[x];d[x]=d[x+1];d[x+1]=trader; }
			tempsnd=hi_clip; tempsnd=low_clip;   } break;
		default: 
			NSRunAlertPanel(@"Invalid Format", 
				@"This trader=d[x];d[x]=d[x+1];d[x+1]=trader; cannot be performed with this particular sound format." , 
				@"Okay",NULL,NULL);
		}
	
	/* (1998: SNDSwapHostToSound - host order, see swap:.) */
	[moduleController soundChanged];
	return self;
	}




	
- stripLeft:sender
	{
	/* Strips left channel */
	Snd* current=[moduleController currentSound];
	SndView* currentSoundView=[moduleController currentSoundView];
	Snd* newSound;
	
	int format=[current dataFormat];
	int channelCount=[current channelCount];
	int sampleCount=[current lengthInSampleFrames];

	void* data;
	unsigned char* data8;
	signed short* data16;
	void* newdata;
	unsigned char* newdata8;
	signed short* newdata16;
	
	unsigned int firstSample, sampleLength;
	
	if (current==NULL)
		{
		NSRunAlertPanel(@"No Sound", 
			@"There is no sound with which to perform this operation." , 
			@"Okay",NULL,NULL);
		return self;
		}

	if ([current channelCount]!=2)
		{
		NSRunAlertPanel(@"Incorrect Number of Channels", 
			@"This sound is not stereo." , 
			@"Okay",NULL,NULL);
		return self;
		}

	[moduleController stop];
	[current compactSamples];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];		

	/* 1998: newSound=[[[Sound alloc] init] autorelease];
	   [newSound setDataSize: [current sampleSizePerChannel]*[current
	   sampleCount] dataFormat: format samplingRate: [current
	   samplingRate] channelCount: 1 infoSize: [current infoSize]];
	   (the 1998 infoSize: argument sized a fresh, zero-filled info
	   region - the module never writes an info string, so the SndKit
	   sound's nil info is the same presentation: the app's view maps
	   a nil info to the empty string).  SndKit has no setDataSize:,
	   so the sound is built directly with the documented initializer
	   in that shape (the WaveBuilder port made the same change). */
	newSound=[[Snd alloc]
		initWithFormat:   format
		channelCount: 1
		frames:       sampleCount
		samplingRate: [current samplingRate]];

	data=(void*)[current bytes];
	data8=(char*)data;
	data16=(signed short*)data;
	newdata=(void*)[newSound bytes];
	newdata8=(char*)newdata;
	newdata16=(signed short*)newdata;

	/* (1998: SNDSwapSoundToHost - host order, see swap:.) */
	
	/* (1998: SNDSwapSoundToHost - host order, see swap:.) */
	
	[[moduleController currentSoundView] 
		getSelection: &firstSample size: &sampleLength];
	if (!sampleLength) {firstSample=0;sampleLength=sampleCount;}	


	switch(format)
		{
		case SND_FORMAT_MULAW_8: 
			{
			int x; char* d=(char*)data; char* nd=(char*)newdata; int y=0;
			for (x=firstSample*channelCount+1;x<(firstSample+sampleLength)*channelCount;x+=2)
				{ nd[y++]=d[x]; }
			} break;
		case SND_FORMAT_LINEAR_8: 			
			{
			char tempsnd; int x; char* d=(char*)data; char* nd=(char*)newdata; int y=0;
			char hi_clip=CHAR_MAX; char low_clip=CHAR_MIN;
			for (x=firstSample*channelCount+1;x<(firstSample+sampleLength)*channelCount;x+=2)
				{ nd[y++]=d[x]; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		case SND_FORMAT_LINEAR_16:  			
			{
			signed short tempsnd; int x; signed short* d=(signed short*)data;   short* nd=(signed short*)newdata; int y=0;
			signed short hi_clip=SHRT_MAX; signed short low_clip=SHRT_MIN;
			for (x=firstSample*channelCount+1;x<(firstSample+sampleLength)*channelCount;x+=2)
				{ nd[y++]=d[x]; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		case SND_FORMAT_FLOAT: 			
			{
			float tempsnd; int x; float* d=(float*)data; float* nd=(float*)newdata; int y=0;
			float hi_clip=1.0; float low_clip=-(1.0);
			for (x=firstSample*channelCount+1;x<(firstSample+sampleLength)*channelCount;x+=2)
				{ nd[y++]=d[x]; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		case SND_FORMAT_DOUBLE: 			
			{
			double tempsnd; int x; double* d=(double*)data;  double* nd=(double*)newdata; int y=0;
			double hi_clip=1.0; double low_clip=-(1.0);
			for (x=firstSample*channelCount+1;x<(firstSample+sampleLength)*channelCount;x+=2)
				{ nd[y++]=d[x]; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		default: 
			NSRunAlertPanel(@"Invalid Format", 
				@"This nd[y++]=d[x]; cannot be performed with this particular sound format." , 
				@"Okay",NULL,NULL);
		}
		
	/* (1998: SNDSwapHostToSound - host order, see swap:.) */
	/* (1998: SNDSwapHostToSound - host order, see swap:.) */
	[currentSoundView setSound:newSound];
	[moduleController newSound:newSound for:currentSoundView];
	return self;
	}



- stripRight:sender
	{
	/* Strips right channel */
	Snd* current=[moduleController currentSound];
	SndView* currentSoundView=[moduleController currentSoundView];
	Snd* newSound;
	
	int format=[current dataFormat];
	int channelCount=[current channelCount];
	int sampleCount=[current lengthInSampleFrames];

	void* data;
	unsigned char* data8;
	signed short* data16;
	void* newdata;
	unsigned char* newdata8;
	signed short* newdata16;
	
	unsigned int firstSample, sampleLength;
	
	if (current==NULL)
		{
		NSRunAlertPanel(@"No Sound", 
			@"There is no sound with which to perform this operation." , 
			@"Okay",NULL,NULL);
		return self;
		}

	if ([current channelCount]!=2)
		{
		NSRunAlertPanel(@"Incorrect Number of Channels", 
			@"This sound is not stereo." , 
			@"Okay",NULL,NULL);
		return self;
		}

	[moduleController stop];
	[current compactSamples];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];		

	/* 1998: newSound=[[[Sound alloc] init] autorelease];
	   [newSound setDataSize: [current sampleSizePerChannel]*[current
	   sampleCount] dataFormat: format samplingRate: [current
	   samplingRate] channelCount: 1 infoSize: [current infoSize]];
	   (the 1998 infoSize: argument sized a fresh, zero-filled info
	   region - the module never writes an info string, so the SndKit
	   sound's nil info is the same presentation: the app's view maps
	   a nil info to the empty string).  SndKit has no setDataSize:,
	   so the sound is built directly with the documented initializer
	   in that shape (the WaveBuilder port made the same change). */
	newSound=[[Snd alloc]
		initWithFormat:   format
		channelCount: 1
		frames:       sampleCount
		samplingRate: [current samplingRate]];

	data=(void*)[current bytes];
	data8=(char*)data;
	data16=(signed short*)data;
	newdata=(void*)[newSound bytes];
	newdata8=(char*)newdata;
	newdata16=(signed short*)newdata;

	/* (1998: SNDSwapSoundToHost - host order, see swap:.) */
	
	/* (1998: SNDSwapSoundToHost - host order, see swap:.) */
	
	[[moduleController currentSoundView] 
		getSelection: &firstSample size: &sampleLength];
	if (!sampleLength) {firstSample=0;sampleLength=sampleCount;}	

	switch(format)
		{
		case SND_FORMAT_MULAW_8: 
			{
			int x; char* d=(char*)data; char* nd=(char*)newdata; int y=0;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount-1;x+=2)
				{ nd[y++]=d[x]; }
			y=x; } break;
		case SND_FORMAT_LINEAR_8: 			
			{
			char tempsnd; int x; char* d=(char*)data; char* nd=(char*)newdata; int y=0;
			char hi_clip=CHAR_MAX; char low_clip=CHAR_MIN;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount-1;x+=2)
				{ nd[y++]=d[x]; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		case SND_FORMAT_LINEAR_16:  			
			{
			signed short tempsnd; int x; signed short* d=(signed short*)data;   short* nd=(signed short*)newdata; int y=0;
			signed short hi_clip=SHRT_MAX; signed short low_clip=SHRT_MIN;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount-1;x+=2)
				{ nd[y++]=d[x]; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		case SND_FORMAT_FLOAT: 			
			{
			float tempsnd; int x; float* d=(float*)data; float* nd=(float*)newdata; int y=0;
			float hi_clip=1.0; float low_clip=-(1.0);
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount-1;x+=2)
				{ nd[y++]=d[x]; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		case SND_FORMAT_DOUBLE: 			
			{
			double tempsnd; int x; double* d=(double*)data;  double* nd=(double*)newdata; int y=0;
			double hi_clip=1.0; double low_clip=-(1.0);
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount-1;x+=2)
				{ nd[y++]=d[x]; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		default: 
			NSRunAlertPanel(@"Invalid Format", 
				@"This nd[y++]=d[x]; cannot be performed with this particular sound format." , 
				@"Okay",NULL,NULL);
		}

/*
	if ([current sampleSizePerChannel]==1)
		{
		int x;
		int y=0;		
		for (x=firstSample*channelCount;  
					x<(firstSample+sampleLength)*channelCount-1; 
					x+=2)
			newdata8[y++]=data8[x];
		}
	else
		{
		int x;
		int y=0;		
		for (x=firstSample*channelCount;
					x<(firstSample+sampleLength)*channelCount-1; 
					x+=2)
			newdata16[y++]=data16[x];
		}
*/


	/* (1998: SNDSwapHostToSound - host order, see swap:.) */

	/* (1998: SNDSwapHostToSound - host order, see swap:.) */
	[currentSoundView setSound:newSound];
	[moduleController newSound:newSound for:currentSoundView];
	return self;
	}







	
- addLeft:sender
	{
	/* Adds left channel */
	Snd* current=[moduleController currentSound];
	SndView* currentSoundView=[moduleController currentSoundView];
	Snd* newSound;
	
	int format=[current dataFormat];
	int channelCount=[current channelCount];
	int sampleCount=[current lengthInSampleFrames];

	void* data;
	unsigned char* data8;
	signed short* data16;
	void* newdata;
	unsigned char* newdata8;
	signed short* newdata16;
	
	unsigned int firstSample, sampleLength;
	
	if (current==NULL)
		{
		NSRunAlertPanel(@"No Sound", 
			@"There is no sound with which to perform this operation." , 
			@"Okay",NULL,NULL);
		return self;
		}

	if ([current channelCount]!=1)
		{
		NSRunAlertPanel(@"Incorrect Number of Channels", 
			@"This sound is not mono." , 
			@"Okay",NULL,NULL);
		return self;
		}

	[moduleController stop];
	[current compactSamples];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];		

	/* 1998: newSound=[[[Sound alloc] init] autorelease];
	   [newSound setDataSize: [current sampleSizePerChannel]*[current
	   sampleCount]*2 dataFormat: format samplingRate: [current
	   samplingRate] channelCount: 2 infoSize: [current infoSize]];
	   (the 1998 infoSize: argument sized a fresh, zero-filled info
	   region - the module never writes an info string, so the SndKit
	   sound's nil info is the same presentation: the app's view maps
	   a nil info to the empty string).  SndKit has no setDataSize:,
	   so the sound is built directly with the documented initializer
	   in that shape (the WaveBuilder port made the same change). */
	newSound=[[Snd alloc]
		initWithFormat:   format
		channelCount: 2
		frames:       sampleCount
		samplingRate: [current samplingRate]];

	data=(void*)[current bytes];
	data8=(char*)data;
	data16=(signed short*)data;
	newdata=(void*)[newSound bytes];
	newdata8=(char*)newdata;
	newdata16=(signed short*)newdata;

	/* (1998: SNDSwapSoundToHost - host order, see swap:.) */
	
	/* (1998: SNDSwapSoundToHost - host order, see swap:.) */

	[[moduleController currentSoundView] 
		getSelection: &firstSample size: &sampleLength];
	if (!sampleLength) {firstSample=0;sampleLength=sampleCount;}	

	switch(format)
		{
		case SND_FORMAT_MULAW_8: 
			{
                        unsigned char mulawzero=SndLinearToMuLaw(0);  // it's probably 127
			int x; char* d=(char*)data; char* nd=(char*)newdata; int y=0;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
                        { nd[y]=mulawzero; nd[y+1]=d[x]; y+=2; }
			} break;
		case SND_FORMAT_LINEAR_8: 			
			{
			char tempsnd; int x; char* d=(char*)data; char* nd=(char*)newdata; int y=0;
			char hi_clip=CHAR_MAX; char low_clip=CHAR_MIN;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ nd[y]=0; nd[y+1]=d[x]; y+=2; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		case SND_FORMAT_LINEAR_16:  			
			{
			signed short tempsnd; int x; signed short* d=(signed short*)data;   short* nd=(signed short*)newdata; int y=0;
			signed short hi_clip=SHRT_MAX; signed short low_clip=SHRT_MIN;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ nd[y]=0; nd[y+1]=d[x]; y+=2; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		case SND_FORMAT_FLOAT: 			
			{
			float tempsnd; int x; float* d=(float*)data; float* nd=(float*)newdata; int y=0;
			float hi_clip=1.0; float low_clip=-(1.0);
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ nd[y]=0; nd[y+1]=d[x]; y+=2; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		case SND_FORMAT_DOUBLE: 			
			{
			double tempsnd; int x; double* d=(double*)data;  double* nd=(double*)newdata; int y=0;
			double hi_clip=1.0; double low_clip=-(1.0);
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ nd[y]=0; nd[y+1]=d[x]; y+=2; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		default: 
			NSRunAlertPanel(@"Invalid Format", 
				@"This nd[y]=0; nd[y+1]=d[x]; y+=2; cannot be performed with this particular sound format." , 
				@"Okay",NULL,NULL);
		}

/*	if ([current sampleSizePerChannel]==1)
		{
		int x;
		int y=0;		
		for (x=firstSample;x<(firstSample+sampleLength);x++)
			{newdata8[y]=0; newdata8[y+1]=data8[x]; y+=2;}
		}
	else
		{
		int x;
		int y=0;		
		for (x=firstSample;x<(firstSample+sampleLength);x++)
			{newdata16[y]=0; newdata16[y+1]=data16[x]; y+=2;}
		}
*/

	/* (1998: SNDSwapHostToSound - host order, see swap:.) */

	/* (1998: SNDSwapHostToSound - host order, see swap:.) */

	[currentSoundView setSound:newSound];
	[moduleController newSound:newSound for:currentSoundView];
	return self;
	}


	

	
- addRight:sender
	{
	/* Adds right channel */
	Snd* current=[moduleController currentSound];
	SndView* currentSoundView=[moduleController currentSoundView];
	Snd* newSound;
	
	int format=[current dataFormat];
	int channelCount=[current channelCount];
	int sampleCount=[current lengthInSampleFrames];

	void* data;
	unsigned char* data8;
	signed short* data16;
	void* newdata;
	unsigned char* newdata8;
	signed short* newdata16;
	
	unsigned int firstSample, sampleLength;
	
	if (current==NULL)
		{
		NSRunAlertPanel(@"No Sound", 
			@"There is no sound with which to perform this operation." , 
			@"Okay",NULL,NULL);
		return self;
		}

	if ([current channelCount]!=1)
		{
		NSRunAlertPanel(@"Incorrect Number of Channels", 
			@"This sound is not mono." , 
			@"Okay",NULL,NULL);
		return self;
		}

	[moduleController stop];
	[current compactSamples];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];		

	/* 1998: newSound=[[[Sound alloc] init] autorelease];
	   [newSound setDataSize: [current sampleSizePerChannel]*[current
	   sampleCount]*2 dataFormat: format samplingRate: [current
	   samplingRate] channelCount: 2 infoSize: [current infoSize]];
	   (the 1998 infoSize: argument sized a fresh, zero-filled info
	   region - the module never writes an info string, so the SndKit
	   sound's nil info is the same presentation: the app's view maps
	   a nil info to the empty string).  SndKit has no setDataSize:,
	   so the sound is built directly with the documented initializer
	   in that shape (the WaveBuilder port made the same change). */
	newSound=[[Snd alloc]
		initWithFormat:   format
		channelCount: 2
		frames:       sampleCount
		samplingRate: [current samplingRate]];

	data=(void*)[current bytes];
	data8=(char*)data;
	data16=(signed short*)data;
	newdata=(void*)[newSound bytes];
	newdata8=(char*)newdata;
	newdata16=(signed short*)newdata;

	/* (1998: SNDSwapSoundToHost - host order, see swap:.) */
	
	/* (1998: SNDSwapSoundToHost - host order, see swap:.) */

	[[moduleController currentSoundView] 
		getSelection: &firstSample size: &sampleLength];
	if (!sampleLength) {firstSample=0;sampleLength=sampleCount;}	

	switch(format)
		{
		case SND_FORMAT_MULAW_8: 
			{
                        unsigned char mulawzero=SndLinearToMuLaw(0);  // it's probably 127
                       	int x; char* d=(char*)data; char* nd=(char*)newdata; int y=0;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
                        { nd[y+1]=mulawzero; nd[y]=d[x]; y+=2; }
			} break;
		case SND_FORMAT_LINEAR_8: 			
			{
			char tempsnd; int x; char* d=(char*)data; char* nd=(char*)newdata; int y=0;
			char hi_clip=CHAR_MAX; char low_clip=CHAR_MIN;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ nd[y+1]=0; nd[y]=d[x]; y+=2; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		case SND_FORMAT_LINEAR_16:  			
			{
			signed short tempsnd; int x; signed short* d=(signed short*)data;   short* nd=(signed short*)newdata; int y=0;
			signed short hi_clip=SHRT_MAX; signed short low_clip=SHRT_MIN;
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ nd[y+1]=0; nd[y]=d[x]; y+=2; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		case SND_FORMAT_FLOAT: 			
			{
			float tempsnd; int x; float* d=(float*)data; float* nd=(float*)newdata; int y=0;
			float hi_clip=1.0; float low_clip=-(1.0);
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ nd[y+1]=0; nd[y]=d[x]; y+=2; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		case SND_FORMAT_DOUBLE: 			
			{
			double tempsnd; int x; double* d=(double*)data;  double* nd=(double*)newdata; int y=0;
			double hi_clip=1.0; double low_clip=-(1.0);
			for (x=firstSample*channelCount;x<(firstSample+sampleLength)*channelCount;x++)
				{ nd[y+1]=0; nd[y]=d[x]; y+=2; }
			tempsnd=hi_clip; tempsnd=low_clip;  y=x; } break;
		default: 
			NSRunAlertPanel(@"Invalid Format", 
				@"This nd[y+1]=0; nd[y]=d[x]; y+=2; cannot be performed with this particular sound format." , 
				@"Okay",NULL,NULL);
		}


/*
	if ([current sampleSizePerChannel]==1)
		{
		int x;
		int y=0;		
		for (x=firstSample;x<(firstSample+sampleLength);x++)
			{newdata8[y+1]=0; newdata8[y]=data8[x]; y+=2;}
		}
	else
		{
		int x;
		int y=0;		
		for (x=firstSample;x<(firstSample+sampleLength);x++)
			{newdata16[y+1]=0; newdata16[y]=data16[x]; y+=2;}
		}
*/
	/* (1998: SNDSwapHostToSound - host order, see swap:.) */

	/* (1998: SNDSwapHostToSound - host order, see swap:.) */

	[currentSoundView setSound:newSound];
	[moduleController newSound:newSound for:currentSoundView];
	return self;
	}

	
@end



