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

  MarksInspector.[h|m]
  Sean Luke

  MarksInspector is the inspector object that handles the "Marks" inspector.
  
  ****************************************************************************/

#import "MarksInspector.h"
#import "ResoundNibs.h"
#import "FileController.h"
#import "InspectorManager.h"
#import "ResoundMiscSoundView.h"
#import <AppKit/AppKit.h>

@implementation MarksInspector


/**** init
  Initializes the inspector
*/

- init
    {
    id returnval=[super init];
    windowsLoaded=0;
    x_option=@"";
    y_option=@"";
    return returnval;
    }

/**** GetInspector:
  Returns the inspector view.  May need to load it.
*/

- getInspector:sender
    {
    if (!windowsLoaded)
	{
	[ResoundNibs loadNibNamed: @"MarksInspector" owner:self];
	windowsLoaded=1;
	}
    return inspector;
    }

/**** marksChanged:
  Updates the inspector.
*/

- marksChanged:sender
    {
    id sound_view=[fileController currentSoundView:self];
    
    if ([inspectorController marksShowing])
	{
	if (sound_view!=nil) 
	    {
	    int x_format=[sound_view minorTickSpacingFormat];
	    int y_format=[sound_view yDisplayFormat];
	    
	    [ticks setIntValue:[sound_view xAxisDisplayed]];
	    [scroll_to_reflect setIntValue:[sound_view scrollToReflectPlaying]];
	    [amplitude setIntValue:[sound_view yAxisDisplayed]];
	    [zero_line setIntValue:[sound_view zeroLineDisplayed]];

	    [major_tick_field setIntValue:[sound_view majorTickSpacing]];
	    [minor_tick_field setFloatValue:[sound_view minorTickSpacing]];
	

	    if (x_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES)
		{
		[minor_tick_menu setTitle: @"Samples"];
		}
	    else if (x_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SECONDS)
		{
		[minor_tick_menu setTitle: @"Seconds"];
		}
	    else // x_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT
		{
		[minor_tick_menu setTitle: @"Percent"];
		}
	    	    
	    if (y_format==MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_DECIBEL)
		{
		[amplitude_menu setTitle: @"Decibel"];
		}
	    else if (y_format==MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_SIXTEEN)
		{
		[amplitude_menu setTitle: @"16-Point"];
		}
	    else if (y_format==MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTY)
		{
		[amplitude_menu setTitle: @"20-Point"];
		}
	    else // (y_format==MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTYFOUR)
		{
		[amplitude_menu setTitle: @"24-Point"];
		}
	    }
	}
    return self;
    }





/**** changeMarks:
  Modifies the current soundview according to the inspector settings.
*/

- changeMarks:sender
    {
    int x_format,y_format; //label_format;
    NSString* temp;
    id sound_view=[fileController currentSoundView:self];
    if (sound_view!=nil) 
	{
        temp=[amplitude_menu title];
        if (![y_option isEqualToString:@""])
            temp=y_option;

	if ([temp isEqualToString: @"Decibel"])
	    {
	    y_format=MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_DECIBEL;
            }
	else if ([temp isEqualToString: @"16-Point"])
	    {
	    y_format=MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_SIXTEEN;
	    }
	else if ([temp isEqualToString: @"20-Point"])
	    {
	    y_format=MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTY;
	    }
	else y_format=MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTYFOUR;

	temp=[minor_tick_menu title];
    if (![x_option isEqualToString:@""]) 
        temp=x_option;
	
	if ([temp isEqualToString: @"Seconds"])
	    {
	    x_format=MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SECONDS;
	    }
	else if ([temp isEqualToString: @"Samples"])
	    {
	    x_format=MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES;
	    }
	else x_format=MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT;
	
	[sound_view update:
	 [ticks intValue]:
	 [amplitude intValue]:
	 1:			
	 [zero_line intValue]:
       UPDATESOUNDVIEW_XAXIS_DISPLAY_FORMAT_TICKS:		// hard-set right now
	 [major_tick_field intValue]:
	 [minor_tick_field floatValue]:
       x_format:
       y_format:
	 [scroll_to_reflect intValue]];
	
	/*thisSize=[[window contentView] contentSize];
	thisRect=[sound_view bounds];
	// now modify the height based on whether or not you're drawing a ruler
	need_ruler= [sound_view xAxisDisplayed];
	[sound_view sizeTo: thisRect.size.width : thisSize.height-
	 (need_ruler ? MISCSOUNDVIEW_RULER_HEIGHT + MISCSOUNDVIEW_PLAY_MARK_HEIGHT : 0)];*/
	
	//[sound_view wipeClean];  // item no longer exists
	[sound_view display];  /* this may or may not be sufficient! */
	[self update:self];	       /* inserted to change to default values 
					  if users' are inappropriate */
	}
    return self;
    }


/**** Update:
  Updates the inspector.
*/

- update:sender
    {
    return [self marksChanged:sender];
    }




/**** setTo...  methods
  These methods exist because menus aren't "changed" until they're chosen.  this
  is a real stupidity on NeXT's part, but...oh, well.
*/

- setToSamples:sender
    {
    x_option=@"Samples";
    [self changeMarks:self];
    x_option=@"";
    return self;
    }

- setToPercent:sender
    {
    x_option=@"Percent";
    [self changeMarks:self];
    x_option=@"";
    return self;
    }

- setToSeconds:sender
    {
    x_option=@"Seconds";
    [self changeMarks:self];
    x_option=@"";
    return self;
    }

- setToSixteen:sender
    {
    y_option=@"16-Point";
    [self changeMarks:self];
    y_option=@"";
    return self;
    }

- setToTwenty:sender
    {
    y_option=@"20-Point";
    [self changeMarks:self];
    y_option=@"";
    return self;
    }

- setToTwentyFour:sender
    {
    y_option=@"24-Point";
    [self changeMarks:self];
    y_option=@"";
    return self;
    }

- setToDecibel:sender
    {
    y_option=@"Decibel";
    [self changeMarks:self];
    y_option=@"";
    return self;
    }

@end

