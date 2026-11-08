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

  InspectorManager.[h|m]
  Sean Luke
  
  The InspectorManager handles Resound's inspector and its inspector objects.
  
  ****************************************************************************/



#import "InspectorManager.h"
#import "ResoundNibs.h"
#import "AttributesInspector.h"
#import "SelectionInspector.h"
#import "ZoomInspector.h"
#import "MarksInspector.h"
#import "InfoStringInspector.h"

#import "FileController.h"
#import <AppKit/AppKit.h>
#import <string.h>
#import <stdio.h>

@implementation InspectorManager



/**** init
  Initializes the inspector.
*/

- init
    {
    id returnval=[super init];
    [ResoundNibs loadNibNamed: @"Inspector" owner:self];
    nothingView=[[nothingInspector contentView] retain];
    contentView=nil;
    inspectorOn=NO;
    inspectorsLoaded=NO;
    return returnval;
    }


/**** LoadInspectors
  Loads the inspectors (duh).
*/

- loadInspectors				// a private method
    {
/* just in case... */
if (attributesView!=nil) [attributesView release];
if (selectionView!=nil) [selectionView release];
if (zoomView!=nil) [zoomView release];
if (marksView!=nil) [marksView release];
if (infoStringView!=nil) [infoStringView release];

/* okay, now....*/
    attributesView=[[[attributesInspector getInspector:self] contentView] retain];
    selectionView=[[[selectionInspector getInspector:self] contentView] retain];
    zoomView=[[[zoomInspector getInspector:self] contentView] retain];
    marksView=[[[marksInspector getInspector:self] contentView] retain];
    infoStringView= [[[infoStringInspector getInspector:self] contentView] retain];
    currentView=attributesView;
    inspectorsLoaded=YES;
    return self;
    }



- (void) awakeFromNib
        {
        [self loadInspectors];
        }



- (void) dealloc
	{
if (attributesView!=nil) [attributesView release];
if (selectionView!=nil) [selectionView release];
if (zoomView!=nil) [zoomView release];
if (marksView!=nil) [marksView release];
if (infoStringView!=nil) [infoStringView release];
if (nothingView!=nil) [nothingView release];
[super dealloc];
}



/**** AddView:
  Makes this_view the current displayed subview in the inspector window.
*/

- addView: this_view						// a private method
    {
    if (contentView==nil)
	{
	[inspectorView addSubview:this_view];
	contentView=this_view;
	[this_view display];
	}
    else if (contentView!=this_view)
	{
	[inspectorView replaceSubview:contentView with: this_view];
	contentView=this_view;
	[this_view display];
	}
    // else the Content View is already Current View
    return self;
    }



/**** ShowView
  Displays the current subview, else displays a "No Sound" blank view.
*/


- showView						// a private method
    {
    if (!inspectorsLoaded) [self loadInspectors];
    if (inspectorOn)
        [self addView:currentView];
    else
        [self addView: nothingView];
    return self;
    }




/**** Update
  Updates the inspectors.
*/


- update
    {
    if (inspectorOn && inspectorsLoaded)
	if ([fileController currentWindow:self])
	    if ([inspector isVisible])
		{
		if (currentView==attributesView) 
		    {
            [attributesInspector update:self];
        }
		else if (currentView==zoomView) 
		    {
		    [zoomInspector update:self];
		    }
		else if (currentView==selectionView) 
		    {
		    [selectionInspector update:self];
		    }
		else if (currentView==marksView)
		    {
		    [marksInspector update:self];
		    }
		else if (currentView==infoStringView)
		    {
		    [infoStringInspector update:self];
		    }
		else // (currentView==nil) 
		    printf ("Inspector Manager ERROR:  CurrentView is nil\n");
		[inspectorView display];
		}
    return self;
    }



/**** DisplayInspector:
  Displays the inspector and makes it key.
*/


- displayInspector:sender
    {
    if (!inspectorsLoaded) [self loadInspectors];
    [inspector makeKeyAndOrderFront:self];
    [self showView];
    [self update];
    return self;
    }




/**** DisplayFoo.... methods
  Display each inspector.  These methods are called by the pop-up menu items
  in the inspector window.
*/

- displayAttributes:sender
    {
    if (!inspectorsLoaded) [self loadInspectors];
    [popUpListButton setTitle:@"Attributes"];
    if (![inspector isVisible]) [inspector makeKeyAndOrderFront:self];
    currentView=attributesView;
    [self showView];
    if (inspectorOn) [attributesInspector update:self];
    return self;
    }

- displaySelection: sender
    {
    if (!inspectorsLoaded) [self loadInspectors];
    [popUpListButton setTitle:@"Selection"];
    if (![inspector isVisible]) [inspector makeKeyAndOrderFront:self];
    currentView=selectionView;
    [self showView];
    if (inspectorOn) [selectionInspector update:self];
    return self;
    }

- displayZoom:sender
    {
    if (!inspectorsLoaded) [self loadInspectors];
    [popUpListButton setTitle:@"Zoom"];
    if (![inspector isVisible]) [inspector makeKeyAndOrderFront:self];
    currentView=zoomView;
    [self showView];
    if (inspectorOn) [zoomInspector update:self];
    return self;
    }


- displayMarks:sender
    {
    if (!inspectorsLoaded) [self loadInspectors];
    [popUpListButton setTitle:@"Marks"];
    if (![inspector isVisible]) 	[inspector makeKeyAndOrderFront:self];
    currentView=marksView;
    [self showView];
    if (inspectorOn) [marksInspector update:self];
    return self;
    }


- displayInfoString:sender
    {
    if (!inspectorsLoaded) [self loadInspectors];
    [popUpListButton setTitle:@"Text"];
    if (![inspector isVisible]) [inspector makeKeyAndOrderFront:self];
    currentView=infoStringView;
    [self showView];
    if (inspectorOn) [infoStringInspector update:self];
    return self;
    }




/**** FooShowing... methods
  Indicates if any inspectors are currently being displayed (and might need to
  be updated) by  inspector in particular. 
*/


- (BOOL) infoShowing
    {
    if (inspectorOn)
	if ([inspector isVisible])
	    if (currentView==attributesView) return YES;
    return NO;
    }


- (BOOL) zoomShowing	
    {
    if (inspectorOn)
	if ([inspector isVisible])
	    if (currentView==zoomView) return YES;
    return NO;
    }


- (BOOL) selectionShowing
    {
    if (inspectorOn)
	if ([inspector isVisible])
	    if (currentView==selectionView) return YES;
    return NO;
    }

- (BOOL) marksShowing
    {
    if (inspectorOn)
	if ([inspector isVisible])
	    if (currentView==marksView) return YES;
    return NO;
    }


- (BOOL) infoStringShowing
    {
    if (inspectorOn)
	if ([inspector isVisible])
	    if (currentView==infoStringView) return YES;
    return NO;
    }





/**** InspectorWindow
  Returns the inspector window
*/


- inspectorWindow
    {
    return inspector;
    }



/**** TurnOnInspector
  Turns on the inspector so it's displaying information.
*/

- turnOnInspector
    {
    inspectorOn=YES;
    [self showView];
    return self;
    }

/**** TurnOffInspector
  Turns off the inspector.
*/

- turnOffInspector
    {
    inspectorOn=NO;
    [self showView];
    return self;
    }

@end
