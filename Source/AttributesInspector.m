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
/****************************************************************************

  AttributesInspector.[h|m]
  Sean Luke

  The AttributesInspector handles the Attributes inspector, which contains stuff like
  the sound type and sound length, file name, and whether or not the sound
  is fragmented.
  
  ****************************************************************************/



#import "AttributesInspector.h"
#import "ResoundNibs.h"
#import "FileController.h"
#import "InspectorManager.h"
#import <AppKit/AppKit.h>
#import <SoundKit/SoundKit.h>

@implementation AttributesInspector


/**** init
  Initializes the inspector 
*/

- init
    {
    id returnval=[super init];
    infoWindowLoaded=0;
    return returnval;
    }


/**** GetInspector:
  Loads (if needed) and returns the inspector. 
*/

- getInspector:sender
    {
    if (!infoWindowLoaded)
	{
	[ResoundNibs loadNibNamed: @"AttributesInspector" owner:self];
	infoWindowLoaded=1;
	}
    infoWindow=[inspectorController inspectorWindow];
    return inspector;
    }





/**** NoWindow:
  Sets the inspector to 0-default values.  I believe this is a legacy method. 
*/

- noWindow
    {
    if (infoWindowLoaded)
	if ([inspectorController infoShowing])
	    {

	    [infoWindow disableFlushWindow];
	    
	    [format setStringValue: @""];
	    [samples setIntValue:0];
	    [seconds setIntValue:0];
	    [channels setIntValue:0];
	    [fragmented setStringValue: @""];
	    [playOrDisplay setStringValue: @""];
	    [rate setStringValue: @""];
	    
	    [infoWindow enableFlushWindow];
	    [infoWindow flushWindowIfNeeded];
	    }
    
    return self;
    }




/**** ChangeInfo:
  Updates the information in the inspector. 
*/


- changeInfo:thisSound
    {
    int dataform;
    double datarate;
    id sound_view=[fileController currentSoundView:self];
    
    if (infoWindowLoaded)
	if ([inspectorController infoShowing])
	    {

	    [infoWindow disableFlushWindow];
	    
	    // SET STANDARD INFORMATION
	    
	    [channels setIntValue:[thisSound channelCount]];
	    [samples setIntValue:[thisSound sampleCount]];
	    if ([thisSound sampleCount]==0)
		{[seconds setFloatValue:0.0];}
	    else
		{
		[seconds setFloatValue:(float) 
		 (((double)[thisSound sampleCount])/[thisSound samplingRate])];
		}

	    dataform=[thisSound dataFormat];

	    if ([thisSound isEmpty])
		[fragmented setStringValue:@"Empty Sound"];
	    else if ([thisSound needsCompacting])
		[fragmented setStringValue:@"fragmented Sound"];
	    else [fragmented setStringValue: @""];
	    
	    if (![thisSound isPlayable])
		{
		if (dataform==SND_FORMAT_DSP_CORE||
		    dataform==SND_FORMAT_COMPRESSED||
		    dataform==SND_FORMAT_COMPRESSED_EMPHASIZED||
		    dataform==SND_FORMAT_DSP_COMMANDS)
		    [playOrDisplay setStringValue: @"Unplayable and Undisplayable Format"];
		else
		    [playOrDisplay setStringValue: @"Unplayable Format"];
		}
	    else if (dataform==SND_FORMAT_DSP_CORE||
		     dataform==SND_FORMAT_COMPRESSED||
		     dataform==SND_FORMAT_COMPRESSED_EMPHASIZED||
		     dataform==SND_FORMAT_DSP_COMMANDS)
		[playOrDisplay setStringValue: @"Undisplayable Format"];
	    else [playOrDisplay setStringValue: @""];
	    

	    // SET RATE
	    
	    datarate=[thisSound samplingRate];
	    [rate setStringValue: @""];
	    if ((int)datarate==(int)SND_RATE_CODEC)
		{[rate setStringValue: @"8.012 KHz"];}
	    else if (datarate==SND_RATE_LOW)
		{[rate setStringValue: @"22.05 KHz"];}
	    else if (datarate==SND_RATE_HIGH)
		{[rate setStringValue: @"44.10 KHz"];}
	    else if (datarate>0)		// in case of error...
		{
            NSString* s;
            if (datarate>=1000) s=[NSString stringWithFormat:@"%f KHz",datarate/1000.0];
		else s=[NSString stringWithFormat:@"%f Hz",datarate];
		[rate setStringValue:s];
		}
	    
	    // SET FORMAT
	    
	    [format setStringValue: @""];
	    if (dataform==SND_FORMAT_MULAW_8)
		{[format setStringValue: @"8-Bit Mu-Law (NeXT Microphone)"];}
	    else if (dataform==SND_FORMAT_LINEAR_8)
		{[format setStringValue: @"8-Bit Linear"];}
	    else if (dataform==SND_FORMAT_LINEAR_16)
		{[format setStringValue: @"16-Bit Linear"];}
	    else if (dataform==SND_FORMAT_LINEAR_24)
		{[format setStringValue: @"24-Bit Linear"];}
	    else if (dataform==SND_FORMAT_LINEAR_32)
		{[format setStringValue: @"32-Bit Linear"];}
	    else if (dataform==SND_FORMAT_FLOAT)
		{[format setStringValue: @"Floating Point"];}
	    else if (dataform==SND_FORMAT_DOUBLE)
		{[format setStringValue: @"Double-Precision Floating Point"];}
	    else if (dataform==SND_FORMAT_INDIRECT)
		{[format setStringValue: @"Indirect"];}
	    else if (dataform==SND_FORMAT_DSP_CORE)
		{[format setStringValue: @"DSP Instruction Code"];}
	    else if (dataform==SND_FORMAT_DSP_DATA_8)
		{[format setStringValue: @"8-Bit DSP Data"];}
	    else if (dataform==SND_FORMAT_DSP_DATA_16)
		{[format setStringValue: @"16-Bit DSP Data"];}
	    else if (dataform==SND_FORMAT_DSP_DATA_24)
		{[format setStringValue: @"24-Bit DSP Data"];}
	    else if (dataform==SND_FORMAT_DSP_DATA_32)
		{[format setStringValue: @"32-Bit DSP Data"];}
	    else if (dataform==SND_FORMAT_DISPLAY)
		{[format setStringValue: @"SoundView Display Data"];}
	    else if (dataform==SND_FORMAT_MULAW_SQUELCH)
		{[format setStringValue: @"8-bit Squelched Mu-Law"];}
	    else if (dataform==SND_FORMAT_EMPHASIZED)
		{[format setStringValue: @"16-Bit Emphasized"];}
	    else if (dataform==SND_FORMAT_COMPRESSED)
		{[format setStringValue: @"16-Bit Compressed"];}
	    else if (dataform==SND_FORMAT_COMPRESSED_EMPHASIZED)
		{[format setStringValue: @"16-Bit Emphasized, Compressed"];}
	    else if (dataform==SND_FORMAT_DSP_COMMANDS)
		{[format setStringValue: @"DSP Code"];}
	    else 			// (dataform==SND_FORMAT_UNSPECIFIED or something else)
		{[format setStringValue: @"Unknown"];}
	    
	    if (sound_view!=NULL)
		{
		if ([sound_view displayMode]==NX_SOUNDVIEW_MINMAX)
		    {
		    [display_matrix selectCell:min_max_button];
		    }
		else
		    {
		    [display_matrix selectCell:oscilliscopic_button];
		    }
		}
	    
	    [infoWindow enableFlushWindow];
	    [infoWindow flushWindow];
	    }
    return self;
    }




/**** changeDisplayModeToMinMax:
  Changes the display mode of the current soundview to MinMax. 
*/

- changeDisplayModeToMinMax:sender
    {
    id sound_view=[fileController currentSoundView:self];
    if (sound_view!=NULL)
	{
	[sound_view setDisplayMode:NX_SOUNDVIEW_MINMAX];
	}
    return self;
    }



/**** changeDisplayModeToOscilliscopic:
  Changes the display mode of the current soundview to Oscilliscopic.  Note this mode
  has serious DPS bugs in NeXT's SoundKit.
*/

- changeDisplayModeToOscilliscopic:sender
    {
    id sound_view=[fileController currentSoundView:self];
    if (sound_view!=NULL)
	{
	[sound_view setDisplayMode:NX_SOUNDVIEW_WAVE];
	}
    return self;
    }

- update:sender  /* syntactic sugar for an update method for the inspector */
{
    return [self changeInfo:[fileController currentSound:self]];
}



@end
