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

  ResoundScrollView.[h|m]
  Sean Luke
  
  ResoundScrollView is a subclass of ScrollView with a few old hacks to update the
  Selection Manager when the scroller is being clicked on.  There's a good chance
  the need for this object has been eliminated by the MiscSoundView's auto-scroll
  updates.  As such, this object can probably safely go away
  with Rhapsody; see what the behavior is without it perhaps.

  ****************************************************************************/

#import "ResoundScrollView.h"
#import <stdio.h>

/* The 1998 SelectionInspector.h import (which provided the 'update:'
   declaration for the id-typed selectionManager below) is dropped:
   that header still imports the legacy SoundKit umbrella and its unit
   has not landed.  A local bridge declares the one selector used, as
   the console unit did with its view-bridge protocol; the dispatch is
   id-safe (the outlet is nil until the SelectionInspector unit lands). */
@protocol FileSelectionManagerBridge
- update:(id)view;
@end

@implementation ResoundScrollView

/*** setSelectionManager:
  Sets the ScrollView's selection manager.
*/

- setSelectionManager:this_manager
    {
    selectionManager=this_manager;
    return self;
    }


/*** mouseDown:
  updates the Selection Manager
*/

- (void) mouseDown:(NSEvent*) theEvent
    {
    [super mouseDown:theEvent];
    [selectionManager update:self];
    } 


/***
  mouseUp:
  updates the SelectionManager
*/

- (void) mouseUp:(NSEvent *)theEvent
    {
    [super mouseUp:theEvent];
    [selectionManager update:self];
    } 

@end
