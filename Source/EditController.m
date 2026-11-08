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

  EditController.[h|m]
  Sean Luke
  
  The EditController used to be the controller object responsible for zooming,
  scaling, scroll managment, cut/copy/paste bugs, conversion, compacting, etc.
  That was a long time ago; since then most of these functions have been moved
  into the MiscSoundView object; now the EditController is basically the object
  responsible for sound conversions and a few clean-up items.
  
  ****************************************************************************/





#import "EditController.h"
#import "ResoundNibs.h"
#import "FileController.h"
#import <SoundKit/SoundKit.h>


/**** This used to be one of the biggest classes, but most of its gunk has been 
  offloaded into Resound's SoundViews by now. 
  */



@implementation EditController


/**** init
  Initialize the EditController */

- init
    {
    id returnval=[super init];
    windowsLoaded=0;
    return returnval;
    }




/**** Convert:
  Load the Convert panel.  This method is called from a menu item. 
  */

- convert:sender
    {
    if (!windowsLoaded)
	{
    [ResoundNibs loadNibNamed: @"Edit" owner:self];//loads Panels
	windowsLoaded=1;
	}
    [convertPanel  makeKeyAndOrderFront:self];
    return self;
    }




/**** OkayConvert:
  Perform the conversion.  This method is called when the user presses thed
  convert button.
  */

- okayConvert:sender;
    {
    id currentSound=[fileController currentSound:self];
    id currentSoundView=[fileController currentSoundView:self];
    NSString* formatstring;
    int channel_count;
    int format;
    int error;
    float sampling_rate;
    
    if (currentSoundView==nil) 
	{
	NSRunAlertPanel(@"Convert",@"No Sound to Convert",@"Okay",nil,nil);
	return nil;
	}
    
    formatstring=[formatMenu title];
    
    if ([formatstring isEqualToString: @"Double Precision Floating Point"])
	{
	format=SND_FORMAT_DOUBLE;
	}
    else if ([formatstring isEqualToString: @"8-bit Linear"])
	{
	format=SND_FORMAT_LINEAR_8;
	}
    else if ([formatstring isEqualToString: @"16-bit Linear"])
	{
	format=SND_FORMAT_LINEAR_16;
	}
    else if ([formatstring isEqualToString: @"16-bit Emphasized"])
	{
	format=SND_FORMAT_EMPHASIZED;
	}
    else if ([formatstring isEqualToString: @"16-bit Compressed"])
	{
	format=SND_FORMAT_COMPRESSED;
	}
    else if ([formatstring isEqualToString: @"16-bit Emphasized, Compressed"])
	{
	format=SND_FORMAT_COMPRESSED_EMPHASIZED;
	}
    else if ([formatstring isEqualToString: @"24-bit Linear"])
	{
	format=SND_FORMAT_LINEAR_24;
	}
    else if ([formatstring isEqualToString: @"32-bit Linear"])
	{
	format=SND_FORMAT_LINEAR_32;
	}
    else if ([formatstring isEqualToString: @"Floating Point"])
	{
	format=SND_FORMAT_FLOAT;
	}
    else // "8-bit Mu-Law"  -- the default
	{
	format=SND_FORMAT_MULAW_8;
	}
    
    if ([[[channelMatrix selectedCell] title] isEqualToString: @"Mono"])
	{
	channel_count=1;
	}
    else		// Stereo--NeXT's Sounds don't allow more than stereo playing!
	{
	channel_count=2;
	}

    if ([[[samplingRateMatrix selectedCell] title] isEqualToString: @"8.012 KHz"])
	{
	sampling_rate=SND_RATE_CODEC;
	}
    else if ([[[samplingRateMatrix selectedCell] title] isEqualToString: @"22.05 KHz"])
	{
	sampling_rate=SND_RATE_LOW;
	}
    else if ([[[samplingRateMatrix selectedCell] title] isEqualToString: @"44.10 KHz"])		
	{
	sampling_rate=SND_RATE_HIGH;
	}
    else if ([samplingRateField floatValue]>0)	// other sampling rate...
	{
	sampling_rate=[samplingRateField floatValue];
	}
    else	// invalid rate...
	{
	NSRunAlertPanel(@"Convert", @"Invalid Rate", @"Okay",nil,nil);
	return nil;
	}

// first be nice if the SoundView's got data on the pasteboard
	[currentSoundView checkForCurrentDataOnPasteboard];

// now convert that sucker
    error=[currentSoundView convertToFormat: format 
	 samplingRate:   sampling_rate 
	 channelCount:   channel_count];
    
    if (error!=SND_ERR_NONE)
	{
	NSRunAlertPanel(@"Convert", @"Cannot Convert Sound", @"Okay",nil,nil);
	return nil;
	}

    // inform the file controller...
    
    [fileController soundChanged:currentSound];
    
    return self;
    }


/**** TurnOnMenu:
  Enables the Compact menu item.  Used to be a lot more items, but now that's it.
*/

- turnOnMenu:sender
    {
    [compactButton setEnabled:YES];
    return self;
    }


/**** TurnOffMenu:
  Disables the Compact menu item.
*/

- turnOffMenu:sender
    {
    [compactButton setEnabled:NO];
    return self;
    }


/**** CompactSound:
  Compacts the current sound. 
*/


- compactSound:sender
    {
    [[fileController currentSound:self] compactSamples];
    [fileController soundChanged: [fileController currentSound:self]];
    return self;
    }


@end
