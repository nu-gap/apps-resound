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

  ZoomInspector.[h|m]
  Sean Luke
  
  ZoomInspector controls the Zoom Inspector.  Zooming is a weird beast math-wise,
  so there's some black majick in the ResoundMiscSoundView to handle this.  This
  simplifies the Zoom Inspector's logic thankfully.

  ****************************************************************************/



#import "ZoomInspector.h"
#import "ResoundNibs.h"
#import "InspectorManager.h"
#import "FileController.h"
#import <AppKit/AppKit.h>
#import <SoundKit/SoundKit.h>
#import "ResoundMiscSoundView.h"
#import <stdio.h>


@implementation ZoomInspector


/*** init
  initializes the zoom inspector
*/

- init
    {
    id returnval=[super init];
    windowsLoaded=0;
    return returnval;
    }


/*** GetInspector:
  Loads and sets up and returns the inspector.
*/

- getInspector:sender
    {
    if (!windowsLoaded)
	{
	[ResoundNibs loadNibNamed: @"ZoomInspector" owner:self];
	windowsLoaded=1;
	}
    return inspector;
    }



/*** setContinuousZoom:
  Sets the inspector to continuously update the sound view as the zoom knob is
  being frobbed.
*/

- setContinuousZoom: (BOOL) zoomOn
    {
    id soundView=[fileController currentSoundView:self];
    if (soundView!=nil)
	{
	[soundView setContinuousZoom:zoomOn];
	[zoomSlider setContinuous: zoomOn];
	[continuous_button setIntValue: [zoomSlider isContinuous]];
	}
    return self;
    }



/*** toggleContinuousZoom:
  Toggles whether the inspector continuously updates the sound view as the zoom knob is
  being frobbed.  Called from a button on the zoom inspector.
*/

- toggleContinuousZoom:sender
    {
    id soundView=[fileController currentSoundView:self];
    if (soundView!=nil)
	{
	[soundView setContinuousZoom:(BOOL) [continuous_button intValue]];
	[zoomSlider setContinuous: (BOOL) [continuous_button intValue]];
	}
    return self;
    }	


/*** update:
  Updates the zoom controller.
*/


- update:sender
    {
    id soundView=[fileController currentSoundView:self];
    double scroll_value;
    if ([inspectorController zoomShowing]&&soundView!=nil)
	{
	scroll_value=[soundView scrollValue];
	if (scroll_value!=-1.0) 
	    {
	    [zoomSlider setFloatValue:scroll_value];
	    [zoomField  setFloatValue:(float)scroll_value];
	    if (soundView!=nil)
		{
		[reductionField setFloatValue:[soundView reductionFactor]];
		[self setContinuousZoom:[soundView continuousZoom]];
		}
	    return self;
	    }
	}
    return nil;
    }


/*** takeFloatValueFromMe:
  Called from the zoom knob.
  Changes the zoom value of the current sound view to reflect the float value
  of the zoom knob..
*/

- takeFloatValueFromMe:sender
    {
    id soundView=[fileController currentSoundView:self];
    double scroll_value=[sender doubleValue];
    id currentWindow=[fileController currentWindow:self];
    [currentWindow disableFlushWindow];
    if (soundView) [soundView setScrollValue:scroll_value];
    [zoomField setFloatValue:(float)scroll_value];
    if (soundView!=nil)
	{
	[reductionField setFloatValue:[soundView reductionFactor]];
	[soundView scrollToSelection:self];
	}
    [currentWindow enableFlushWindow];
    [currentWindow flushWindowIfNeeded];
    return self;
    }




/*** zoomFoo methods...
  Perform standard zoom operations as called from menu options.
*/

- zoomAllIn:sender
    {
    id currentSoundView=[fileController currentSoundView:self];
    if (currentSoundView) [currentSoundView zoomAllIn:self];
    [self update:self];				// adjust slider and field
    return self;
    }

- zoomAllOut:sender	
    {
    id currentSoundView=[fileController currentSoundView:self];
    if (currentSoundView) [currentSoundView zoomAllOut:self];
    [self update:self];				// adjust slider and field
    return self;
    }

- zoomToSelection:sender
    {
    id currentSoundView;
    
    currentSoundView=[fileController currentSoundView:self];
    if (currentSoundView) [currentSoundView zoomToSelection:self];
    [self update:self];				// adjust slider and field
    
    return self;
    }


- zoomOutOneReduction:sender
    {
    id currentSoundView=[fileController currentSoundView:self];
    if (currentSoundView) [currentSoundView zoomOutOneReduction:self];
    [self update:self];				// adjust slider and field

    return self;
    }

- zoomInOneReduction:sender
    {
    id currentSoundView=[fileController currentSoundView:self];
    if (currentSoundView) [currentSoundView zoomInOneReduction:self];
    [self update:self];				// adjust slider and field
    return self;
    }





/*** findSelection:
  Called from the menu option of the same name.  Scrolls the sound view to the current
  selection without changing the zoom.
*/

- findSelection:sender
    {
    id currentSoundView=[fileController currentSoundView:self];
    if (currentSoundView)
	{
	int firstSample, sampleCount;
	[currentSoundView getSelection:&firstSample size:&sampleCount];
	if (![currentSoundView sampleIsVisible:firstSample])
		[currentSoundView scrollToSelection:self];
	}
    return self;
    }

- zoomChanged:sender  /* backward compatability */
{
    return [self update:sender];
}

@end
