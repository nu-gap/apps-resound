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
  
  InfoStringInspector.[h|m]
  Sean Luke
  
  The infoStringInspector is the inspector that manages the object's Info String
  and the "Text" Inspector panel.

  There's a serious bug in NeXT's Info String facility; info strings do not
  persist through various SNDSoundStruct functions.  So Resound must store
  info strings in the Resound SoundView object.
  
  I've cleaned out some dead wood, so let me know if this still works.
  
  ****************************************************************************/





#import "InfoStringInspector.h"
#import "ResoundNibs.h"
#import "FileController.h"
#import "InspectorManager.h"
#import <AppKit/AppKit.h>
#import <SoundKit/SoundKit.h>
#import "ResoundMiscSoundView.h"

@implementation InfoStringInspector


/*** init
  Initializes the inspector
  */

- init
    {
    id returnval=[super init];
    infoWindowLoaded=0;
    return returnval;
    }




/*** GetInspector:
  Loads (if needed) the inspector and returns it.
  */

- getInspector:sender
    {
    if (!infoWindowLoaded)
	{
	[ResoundNibs loadNibNamed: @"InfoStringInspector" owner:self];
	infoWindowLoaded=1;
	}
    infoWindow=[inspectorController inspectorWindow];
    return inspector;
    }


/*** NoWindow
  Sets the Inspector to a 0-default setting.  This is probably a legacy method now.
  */

- noWindow
    {
    if (infoWindowLoaded)
	if ([inspectorController infoShowing])
	    {
	    [infoWindow disableFlushWindow];
	    [infoString setString:@""];
        [infoWindow enableFlushWindow];
	    [infoWindow flushWindowIfNeeded];
	    }
    
    return self;
    }



/*** Update:
  Updates the inspector.
  */

- update:sender
    {
    ResoundMiscSoundView* sv=[fileController currentSoundView:self];
    
    if (infoWindowLoaded)
	if ([inspectorController infoStringShowing])
	    {

	    [infoWindow disableFlushWindow];
	    
	    if (sv!=nil) [infoString setString:
            [NSString stringWithCString:[sv info]]];
	    else [infoString setString:@""];
	    
	    [infoWindow enableFlushWindow];
	    [infoWindow flushWindow];
	    }
    return self;
    }


/*** Revert:
  Updates the inspector.  Called when the "Revert" button is pressed.
  */

- revert:sender
    {
    return [self update:self];
    }






/*** Okay:
  Changes the sound's info string to the inspector's text.  Called when the user
  presses the "Change" button.
  */

- okay:sender
    {
    // Here we update the sound to reflect new info string
    Sound* curSound=[fileController currentSound:self];
    ResoundMiscSoundView* cv=[fileController currentSoundView:self];

    if (curSound==nil)
	{
	NSRunAlertPanel(@"Text", 
			@"There is no sound to modify.", 
			@"Oops",nil,nil);
	return nil;
	}
    
	{
        [cv setInfo:[[infoString string] lossyCString]];
        [infoString setString:[NSString stringWithCString:[cv info]]];
        [fileController soundChanged:curSound];
	}
    
    return self;
    }


@end
