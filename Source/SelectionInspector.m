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

  SelectionInspector.[h|m]
  Sean Luke
  
  SelectionInspector is the controller object for the Selection inspector.  This
  object is a little different from other inspectors, as it can be updated in
  real-time as the user changes the selection and the window size.  And by typing
  in numbers in the selection area, the user can change the selection.

  An easy addition if you're interested:  currently the user can change the
  selection but not the view.  While changing the *length* of the view is probably
  a bad idea, changing the start or end position of the view would be easy to do
  (changing the start position is trivial, it just would call scrollToSample: 
  in MiscSoundView).
  
  ****************************************************************************/




#import "SelectionInspector.h"
#import "ResoundNibs.h"
#import "FileController.h"
#import "InspectorManager.h"
#import "ResoundMiscSoundView.h"
#import <AppKit/AppKit.h>
#import <SoundKit/SoundKit.h>

@implementation SelectionInspector


/*** secondsTosamples(x,seconds)
  Utility function, converts seconds to samples given the sound's sampling rate.
*/

int secondsTosamples(Sound* x, float seconds)
    {
    return (int) floor(seconds*[x samplingRate]);
    }



/*** percentTosamples(x,percent)
  Utility function, converts percent to samples given a sound's sample count.
*/

int percentTosamples(Sound* x, float percent)
// value from 0 to 100
    {
    if (percent==100.0) return [x sampleCount];
    return (int) floor(percent*[x sampleCount]/100.0);
    }



/*** init
  Initializes the inspector.
  */

- init
    {
    id returnval=[super init];
    windowsLoaded=0;
    return returnval;
    }




/*** update:
  updates the inspector.
*/

- update:sender
    {
    [self changeSelection:sender];
    return self;
    }


/***
  updates the inspector.  This entails a lot of text fields (18), so it's a big but
  repetitive method.
*/

- changeSelection:sender
    {
    int firstSample, sampleCount;
    double samplingRate;
    NSRect visibleRect;
    double reductionFactor;
    double firstViewSample, viewSampleCount;
    float	samples;
    
    if (windowsLoaded)
	{
	if 	([inspectorController selectionShowing])
	    {
	    [selectionWindow disableFlushWindow];
	    
	    samples=(float)[[fileController currentSound:self] sampleCount];
	    samplingRate = (double)[[fileController currentSound:self] samplingRate];
	    [[fileController currentSoundView:self] getSelection: &firstSample
	   size: &sampleCount];
	    [selectionStart setIntValue: firstSample];
	    [selectionLength setIntValue: sampleCount];
	    [selectionEnd setIntValue: firstSample+sampleCount];
	    [selectionSecondsStart setFloatValue: (float)firstSample /samplingRate];
	    [selectionSecondsLength setFloatValue: (float)sampleCount /samplingRate];
	    [selectionSecondsEnd setFloatValue: (float)(firstSample+sampleCount) /samplingRate];
	    if (samples!=0)
		{
		[selectionPercentStart setFloatValue:(float)firstSample/samples*100];
		[selectionPercentLength setFloatValue: (float)sampleCount/samples*100];
		[selectionPercentEnd setFloatValue: ((float)(firstSample+sampleCount))/samples*100];
		}
	    else
		{
		[selectionPercentStart setStringValue:@""];
		[selectionPercentEnd setStringValue:@""];
		[selectionPercentLength setStringValue:@""];
		}

        visibleRect=[[fileController currentSoundView:self] visibleRect];
	    reductionFactor= (double) [[fileController currentSoundView:self] reductionFactor];
	    firstViewSample=(visibleRect.origin.x*reductionFactor);
	    viewSampleCount=(visibleRect.size.width*reductionFactor);
	    [viewStart setIntValue: firstViewSample];
	    [viewLength setIntValue: viewSampleCount];
	    [viewEnd setIntValue: firstViewSample+viewSampleCount];
	    [viewSecondsStart setFloatValue: (float)(firstViewSample/samplingRate)];
	    [viewSecondsLength setFloatValue: (float)(viewSampleCount /samplingRate)];
	    [viewSecondsEnd setFloatValue: (float)((firstViewSample+viewSampleCount) /samplingRate)];
	    if (samples!=0)
		{
		[viewPercentStart setFloatValue: (float) firstViewSample/samples*100];
		[viewPercentLength setFloatValue: (float) viewSampleCount / samples*100];
		[viewPercentEnd setFloatValue: (float) (firstViewSample+viewSampleCount) / samples*100];
		}
	    else	
		{
		[viewPercentStart setStringValue:@""];
		[viewPercentEnd setStringValue:@""];
		[viewPercentLength setStringValue:@""];
		}
	    
      	    [selectionWindow enableFlushWindow];
	    [selectionWindow flushWindowIfNeeded];
	    }
	}

    return self;
    }






/*** Reset:
  Resets the inspector to 0-defaults.
*/

- reset:sender
    {
    if (windowsLoaded)
	{
	if 	([inspectorController selectionShowing])
	    {
	    [selectionStart setIntValue: 0];
	    [selectionLength setIntValue: 0];
	    [selectionEnd setIntValue: 0];
	    [selectionSecondsStart setIntValue:0];
	    [selectionSecondsLength setIntValue:0];
	    [selectionSecondsEnd setIntValue:0];

	    [viewStart setIntValue: 0];
	    [viewLength setIntValue: 0];
	    [viewEnd setIntValue: 0];
	    [viewSecondsStart setIntValue:0];
	    [viewSecondsLength setIntValue:0];
	    [viewSecondsEnd setIntValue:0];
	    }
	}
    
    return self;
    }



/***  GetInspector:
  Loads the inspector and sets it up.
*/

- getInspector:sender
    {
    if (!windowsLoaded)
	{
	[ResoundNibs loadNibNamed: @"SelectionInspector" owner:self];
	windowsLoaded=1;
	}
    selectionWindow=[inspectorController inspectorWindow];
    return inspector;
    }



/*** changeSelectionFoo.... methods
  These methods modify the selection values of the current soundview, depending on
  which text field the user had typed into.
*/

- changeSelectionSamples:sender
    {
    id sound_view=[fileController currentSoundView:self];
    int sc=[[(SoundView*)sound_view sound] sampleCount];	// TypeCast for OS X server
    if (sound_view!=nil)
	{
	if ([selectionStart intValue]<0) [selectionStart setIntValue:0];
	if ([selectionEnd intValue]<0) [selectionEnd setIntValue:0];
	if ([selectionStart intValue]>=sc)
	    [selectionStart setIntValue:sc];
	if ([selectionStart intValue]>=sc)
	    [selectionStart setIntValue:sc];
	if ([selectionEnd intValue]<[selectionStart intValue]) 
	    [selectionEnd setIntValue:[selectionStart intValue]];
	[sound_view setSelection: [selectionStart intValue] size: 
	 [selectionEnd intValue]-[selectionStart intValue]];
	[sound_view scrollToSelection:self];
	}
    [self update:self];
    return self;
    }

- changeSelectionSamplesLength:sender
    {
    id sound_view=[fileController currentSoundView:self];
    int sc=[[(SoundView*)sound_view sound] sampleCount];	// TypeCast for OS X server
    if (sound_view!=nil)
	{
	if ([selectionStart intValue]<0) [selectionStart setIntValue:0];
	if ([selectionLength intValue]<0) [selectionEnd setIntValue:0];
	if ([selectionStart intValue]>=sc)
	    [selectionStart setIntValue:sc];
	if ([selectionLength intValue]>=sc-[selectionStart intValue])
	    [selectionLength setIntValue:sc-[selectionStart intValue]];
	[sound_view setSelection: [selectionStart intValue] size:[selectionLength intValue]];
	[sound_view scrollToSelection:self];
	}
    return [self update:self];
    }

- changeSelectionSeconds:sender
    {
    id sound=[fileController currentSound:self];
    if (sound==nil) return [self update:self];
    [selectionStart setIntValue:secondsTosamples(sound,[selectionSecondsStart floatValue])];
    [selectionEnd setIntValue:secondsTosamples(sound,[selectionSecondsEnd floatValue])];
    return [self changeSelectionSamples:sender];
    } 

- changeSelectionSecondsLength:sender
    {
    id sound=[fileController currentSound:self];
    if (sound==nil) return [self update:self];	
    [selectionStart setIntValue:secondsTosamples(sound,[selectionSecondsStart floatValue])];
    [selectionLength setIntValue:secondsTosamples(sound,[selectionSecondsLength floatValue])];
    return [self changeSelectionSamplesLength:sender];
    } 

- changeSelectionPercent:sender
    {
    id sound=[fileController currentSound:self];
    if (sound==nil) return [self update:self];
    [selectionStart setIntValue:percentTosamples(sound,[selectionPercentStart floatValue])];
    [selectionEnd setIntValue:percentTosamples(sound,[selectionPercentEnd floatValue])];
    return [self changeSelectionSamples:sender];
    } 

- changeSelectionPercentLength:sender
    {
    id sound=[fileController currentSound:self];
    if (sound==nil) return [self update:self];
    [selectionStart setIntValue:percentTosamples(sound,[selectionPercentStart floatValue])];
    [selectionLength setIntValue:percentTosamples(sound,[selectionPercentLength floatValue])];
    return [self changeSelectionSamplesLength:sender];
    } 



#ifdef PASTE_BUG

/*** stillExists:
  Syntactic Sugar for the FileConroller's stillExists: method.
*/

- (BOOL) stillExists:(void*) pointer
    {
    return [fileController stillExists:pointer];
    }

/*** invalidatePasteboard
  Syntactic Sugar for the FileConroller's invalidatePasteboard method.
*/

- invalidatePasteboard
    {
    return [fileController invalidatePasteboard];
    }
#endif

@end
