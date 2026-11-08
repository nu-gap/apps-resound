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

  ResoundMiscSoundView.[h|m]
  Sean Luke
  
  ResoundMiscSoundView contains methods which specialize Resound's version
  of the MiscSoundView.  Many of these are cut/copy/paste fixes for the
  Paste Bug (NeXT's SoundViews cut and copy lazily, so if they go away,
  a subsequent paste can bomb the system).

  To deal with the Paste Bug, Resound adds a category to Pasteboard that
  gives it access to the Pasteboard's owner (the category is called ChangeOwn).

  Other methods set the cursor, set up zooming, perform additional drawing,
  handle auto-updates of playing and zooming, and fix the Info String bug
  (info strings aren't handled correctly by SNDSoundStructs, so Resound
  manages info strings in SoundViews instead of in Sounds).
  
  This object is a rich source of weird bug fixes, odd modifications, you name it.
  Have fun.
  
  ****************************************************************************/


#import "ResoundMiscSoundView.h"
#import "MiscSoundViewRuler.h"
#import <stdio.h>

#ifdef PASTE_BUG

@implementation NSPasteboard(ChangeOwn)

/*** changeOwner:
  Changes the Pasteboard's owner.
*/

- changeOwner:(void*) new_owner
    {
    _owner=new_owner;  /* there's a good chance this doesn't work any more */
    return self;
    }

/*** owner
  Returns the Pasteboard's owner.
*/

- (void*) owner
    {
    return (void*)_owner;  /* there's a good chance this doesn't work any more */
    }
@end

#endif





@implementation ResoundMiscSoundView

- (BOOL)sampleIsVisible:(int)sample
        {
	NSRect vRect=[self visibleRect];
	double rFactor= (double) [self reductionFactor];
	long firstViewSample=(long)(vRect.origin.x*rFactor);
	long viewSampleCount=(long)(vRect.size.width*rFactor);
	if (sample>=firstViewSample && sample <=viewSampleCount+firstViewSample)
		return YES;
	else return NO;
        }


// a known bug in 3.x states that setSound will automatically reset
// the reduction factor of any sound, so only *after* any setSound call, we must
// resset the reduction factor of the sound if we want our own reduction factor.
// see NeXTAnswers 1451.
// this code also attempts to 
- (void) setSound:(Snd*) aSound
{
	double reduction_factor;
	int first_sample,size;
	int scroll_sample;
	
	// Keep old scroll position, reduction factor, selection...

	scroll_sample=[self scrollSample];
        reduction_factor=[self reductionFactor];
        [self getSelection:&first_sample size:&size];

	[super setSound:aSound];
	
	// resupply old scroll position,. reduction factor, selection...

        [self setReductionFactor:reduction_factor];
        [self setSelection:first_sample size:size];
        if (![self sampleIsVisible:first_sample])
        	[self scrollToSample:scroll_sample];
}


/* Dealing With Cut, Copy, and Paste Bugs with freed objects */

#ifdef PASTE_BUG
/*** paste:
  Handles the Paste Bug.  First checks to see if the pasteboard is bad.
  If it isn't it pastes.  Otherwise it invalidates the pasteboard.
  */

- (void) paste:sender
    {
    NSArray* array=[NSArray arrayWithObject:SndPasteboardType];
    id pb=[NSPasteboard generalPasteboard];
    
    if (![[pb availableTypeFromArray:array] isEqualToString:SndPasteboardType])
	{
        /* nothing to paste */
	}
    else if ([selectionInspector stillExists:	
	      (void*)[pb owner]])
	{
        [super paste:sender];
	}
    else
	{
	[selectionInspector invalidatePasteboard];
	/* Now, don't paste */
	}
    }




/*** cut:
  Handles the Paste Bug.  Invalidates the pasteboard if neccessary prior
  to cutting.
  */
- (void) cut:sender
    {
    NSArray* array=[NSArray arrayWithObject:SndPasteboardType];
    id pb=[NSPasteboard generalPasteboard];

    if (([[pb availableTypeFromArray:array]  isEqualToString:SndPasteboardType])&&
	![selectionInspector stillExists: (void*)[pb owner]])
	[selectionInspector invalidatePasteboard];

    [super cut:sender];
    }

/*** copy:
  Handles the Paste Bug.  Invalidates the pasteboard if neccessary prior
  to copying.
  */
- (void) copy:sender
    {
    NSArray* array=[NSArray arrayWithObject:SndPasteboardType];
    id pb=[NSPasteboard generalPasteboard];

    if (([[pb availableTypeFromArray:array] isEqualToString:SndPasteboardType])&&
	![selectionInspector stillExists: (void*)[pb owner]])
	[selectionInspector invalidatePasteboard];
    
    [super copy:sender];
    }
#else
     /*** cut:
       Handles the Paste Bug in a better way.
       */
     - (void) cut:sender
         {
	 int currentCount=[[NSPasteboard generalPasteboard] changeCount];
	 int newCount; 
	 int first; int sampleSize;

	// how big is our data?
         [self getSelection:&first size:&sampleSize];
	 sizeOfDataOnPasteboard=sampleSize * [[self sound] channelCount];
	 if ([[self sound] lengthInSampleFrames]!=0)
         	sizeOfDataOnPasteboard *= ([[self sound] dataSize]/[[self sound] lengthInSampleFrames]);


         // important that you cut FIRST
	 [super cut:sender];
         newCount=[[NSPasteboard generalPasteboard] changeCount];
	 if (newCount!=currentCount)  // we actually did a cut...
		{
		dataOnPasteboard=YES;
        	pasteboardCount=newCount;
		[self retain];
		}
        }

     /*** copy:
       Handles the Paste Bug in a better way.
       */
     - (void) copy:sender
         {
	int currentCount=[[NSPasteboard generalPasteboard] changeCount];
	int newCount;
	int first; int sampleSize;

        // how big is our data?
         [self getSelection:&first size:&sampleSize];
         sizeOfDataOnPasteboard=sampleSize * [[self sound] channelCount];
         if ([[self sound] lengthInSampleFrames]!=0)
                sizeOfDataOnPasteboard *= ([[self sound] dataSize]/[[self sound] lengthInSampleFrames]);

	// important that you copy FIRST
	[super copy:sender];
	newCount=[[NSPasteboard generalPasteboard] changeCount];
	if (newCount!=currentCount)  // we actually did a cut...
	       {
        	dataOnPasteboard=YES;
		pasteboardCount=newCount;
                [self retain];
	       }
         }

- (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type
	{
	// the 1998 SoundView had a bug in this call: it invoked
	// pasteboard:provideData: instead of pasteboard:provideDataForType:
	// (a bug this override was compensating for).  SndKit calls the
	// correct selector, so relay to it the way the 1998 comment said
	// it SHOULD be:
	[super pasteboard:sender provideDataForType:type];
	// at this point we assume that we've provided data and don't have to any more.
	if (dataOnPasteboard) { dataOnPasteboard=NO; }
	}

- (void)pasteboardChangedOwner:(NSPasteboard *)sender
	{
	// superclass doesn't respond to this method.
	// at this point we assume that we've provided data and don't have to any more.
	if (dataOnPasteboard) { dataOnPasteboard=NO; [self autorelease];  }
	}


/**** checkForCurrentDataOnPasteboard
     This method should be called when the object is about ready to be
     modified.  It checks to see if the object has put data on the pasteboard.
     if it does, this method then deals with this issue appropriately.  
   */

- (void)checkForCurrentDataOnPasteboard
	{
	if (dataOnPasteboard &&
	    pasteboardCount==[[NSPasteboard generalPasteboard] changeCount])
		{
		int shouldKeep=0;

		if (sizeOfDataOnPasteboard>MAXIMUM_BYTES_FOR_SILENT_PASTE)
			{
			shouldKeep=(NSRunAlertPanel(@"Pasteboard",
	@"A sound is about to be modified (or eliminated), but it has a very large amount of data listed on the pasteboard as available for pasting. Do you want to officially move this data to the pasteboard, or clear the pasteboard listing?\n\nIf you move the data, it may take a while and consume a lot of memory.\n\nIf you clear the listing, you won't be able to paste what's currently on the pasteboard any more.",@"Keep",@"Clear",nil)
				== NSAlertDefaultReturn);
			}
		else shouldKeep=1;

		if (shouldKeep)
			{
			NS_DURING  // just make sure it's really sound data and
				   // is available!
			
			// suck that data into the pasteboard
			[[NSPasteboard generalPasteboard]
                                dataForType:SndPasteboardType];
			
			NS_HANDLER

                        NSRunAlertPanel(@"Error Panel (No Biggie, don't worry 'bout it)", @"%@", @"OK", nil, nil, localException);

			NS_ENDHANDLER
			}
		else
			{
			// replace the pasteboard with something minor
	                [[NSPasteboard generalPasteboard]
	                        declareTypes: [NSArray arrayWithObject:NSStringPboardType] 
				owner:nil];
                	[[NSPasteboard generalPasteboard]
				setString:@"" forType:NSStringPboardType];
			}
		}
	}

#endif



/*** setCursor:
  Sets the SoundView's | cursor.
  */

- setCursor:this_cursor
    {
    cursor=this_cursor;
    return self;
    }


/*** resetCursorRects:
  Resets the cursor rects and adds the | cursor for the view.
  */

- resetCursorRects
    {
    NSRect visible;
    
    if (cursor!=nil)
	{
	visible=[self visibleRect];
        [self addCursorRect:visible cursor:cursor];
    }
    return self;
    }




/*** continuousZoom
  Returns true if zoom is set to continuous.
  */

- (BOOL) continuousZoom
    {
    return continuousZoom;
    }



/*** updateStuff
  Tells the selection manager to update itself.
  */

- updateStuff
    {
    // Now update the Selection Manager.
    //
    // The 1998 code sent the informal 'update:' message directly.  With
    // SndKit's umbrella headers visible, clang type-checks that argument
    // against SndStreamArchitectureView's update:(NSTimer*) and warns, so
    // the informal call goes through performSelector: instead (the same
    // dynamic dispatch, no compile-time type check):

    if (continuousUpdate && selectionInspector) [selectionInspector performSelector:@selector(update:) withObject:self];
    return self;
    }


/*** drawSelf::
  Tells the selection manager to update itself.  This makes possible
  the selection manager tracking the view and selection of the SoundView.
  */

- (void)drawRect:(NSRect)rects
    {
    [super drawRect:rects];
    if (![rulerView onlyChangePlayMark]) [self updateStuff];
    }



/*** setSelectionManager:
  Sets the selection manager for the ResoundMiscSoundView.
  */
- setSelectionManager: aSelectionManager
    {
    selectionInspector=aSelectionManager;
    return self;
    }


/*** setContinuousUpdate:
  Sets the continuous update for the selection manager.
  */
- setContinuousUpdate:(BOOL) this_update
    {
    continuousUpdate=this_update;
    if (continuousUpdate) 
	{[self setContinuousSelectionUpdates:YES];} else [self setContinuousSelectionUpdates:NO];
    return self;
    }


/*** setContinuousZoom:
  Sets the continuous zoom to true or false.
  */
- setContinuousZoom:(BOOL) this_zoom
    {
    continuousZoom=this_zoom;
    return self;
    }


/*** initFrame:
  Initializes the SoundView.
  */
- initWithFrame:(NSRect)frameRect
    {
    id returnval=[super initWithFrame:frameRect];
    
    continuousZoom=YES;
    continuousUpdate=YES;
    cursor=nil;
    info_string=nil;
    return returnval;
    }




/*** update::::::::::
  Updates the MiscSoundView.  A syntactic sugar cover for set::::::::::
  */
- update:(BOOL) display_the_x_axis:
(BOOL) display_the_y_axis:
(BOOL) display_the_labels:
(BOOL) display_the_zero_line:
(int) this_x_display_format:
(int) this_major_tick_spacing:
(float) this_minor_tick_spacing:
(int) this_minor_tick_spacing_format:
(int) this_y_display_format:
(BOOL) do_scroll_to_reflect_playing
    {
    return [self set:
	    (BOOL) display_the_x_axis:
	    (BOOL) display_the_y_axis:
	    (BOOL) display_the_labels:
	    (BOOL) display_the_zero_line:
	    (int) this_major_tick_spacing:
	    (float) this_minor_tick_spacing:
	    (int) this_minor_tick_spacing_format:
	    (int) this_y_display_format:
	    (BOOL) do_scroll_to_reflect_playing];
    }





/*** RMSV_scroll_to_reduction(scrollValue,ratio)
  Converts a zoom-scroller value from 0 to 1 to a SoundView reduction given
  a known sample-count to display-units ratio.  A lot of this is black majick.
 */

double RMSV_scroll_to_reduction (double scrollValue, double ratio)
// scrollValue must be a number between 1 and 0
// ratio is sample count / display units
// returns -1 if error
// this function considers roundoff to integers,
// and a maximum value at integer point
    {
    if (scrollValue>1.0||scrollValue<0.0) 
	{
	printf ("scroll_to_reduction ERROR:  scrollValue is %f, ratio is%f\n", scrollValue, ratio);
	return -1.0;
	}
    return ceil(pow(ceil(ratio),scrollValue));
    }



/*** RMSV_scroll_to_reduction(scrollValue,ratio)
  Converts a reduction to a zoom-scrollver value given
  a known sample-count to display-units ratio.  A lot of this is black majick.
 */

double RMSV_reduction_to_scroll (double reduction, double ratio)	
// reduction must be a number above 1, preferably < ratio
// ratio is sample count / display units
// returns -1 if error
// this function does not consider roundoff to integers...
// but does consider a maximum value at integer point
    {
    if (reduction<1.0) 
	{
	printf ("reduction_to_scroll ERROR:  reduction is %f, ratio is %f\n", reduction, ratio);
	return -1.0;
	}
    return log(reduction)/log(ceil(ratio));
    }



/*** scrollValue
  Returns the proper setting for the zoom-scroller.
 */


- (double) scrollValue
    {
    NSSize content_size;
    id currentScrollView;
    currentScrollView=[[self superview] superview];
    content_size=[currentScrollView contentSize];
    
    return RMSV_reduction_to_scroll
	( [self reductionFactor],
	 ((double)[[self sound] lengthInSampleFrames])
	 /(double)content_size.width);
    }



/*** setScrollValue:
  Zooms the reduction factor of the soundview to represent a given requested
  zoom-scroller setting.
 */

- setScrollValue:(double) this_value  // this_value must be between 1 and 0
    {
    NSSize content_size;
    double new_reduction_factor;
    int first_sample, number_of_samples;
    id currentScrollView;
    currentScrollView=[[self superview] superview];
    content_size=[currentScrollView contentSize];
    
    [self getSelection:&first_sample size:&number_of_samples];
    
    new_reduction_factor= RMSV_scroll_to_reduction	
	( this_value,
	 ((double)[[self sound] lengthInSampleFrames])
	 /(double)content_size.width);
    
    if (new_reduction_factor!=-1.0)		// it's not an error
	{
	[self setReductionFactor:new_reduction_factor];
	[self setSelection:first_sample size: number_of_samples];
	return self;
	}
    else
	{
	[self setSelection:first_sample size: number_of_samples];
	return nil;
	}
    }



/*** free
  frees the SoundView and the info string
 */


- (void) dealloc
    {
    if (info_string!=nil) [info_string release];
	// it looks like my superior does some cursor drawing
	// that he shouldn't be doing when he's released,
	// because at this point he's not in a window!
	// so we fix that:
    [self setIgnoreShowAndHideCursor:YES];
    [super dealloc];
    // we don't call setIgnoreShowAndHideCursor:NO because [super dealloc]
    // actually marks the object as freed, so this would be a call on a freed
    // object.  It's not needed any more anyway because you can't display
    // a freed object either!
    }



/*** loadInfo
  loads the info string from a sound
 */

- loadInfo:(Snd*)s
    {
    return [self setInfo:[s info]];
    }



/*** info
  returns the current info string 
 */

- (NSString*)info
    {
    return (info_string==nil ? @"" : info_string);
    }




/*** setInfo:
  sets the current info string, enlarging it sufficiently. 
 */

- setInfo:(NSString*)t
    {
    if (info_string!=nil) [info_string release];
    if (t==nil) // happens when it's a new sound (no info string, because
		// a newly-allocated Snd has none)
	{
	info_string=[@"" copy];  // the empty string
	}
    else
	{
	info_string=[t copy];
	}
    return self;
    }


/* This is only here to allow breaks in gdb to land here for testing
   of some nasty SoundKit bugs */
- (void) lockFocus
{
[super lockFocus];
}


/* a real evil soundKit bug appears when you create a new soundView and
   a previous soundView already has a cursor blinking.  When you install
   the first soundView into a scrollView or window, 
   it gets sent a hideCursor message,
   which draws junk to the soundView.  Trouble is, the soundView isn't part
   of a window yet, which initiates a hideous exception.  Very nasty to track
   down. So this method below allows us to "turn off" hiding and showing
   of cursors until we've set the soundView up properly in a window so it
   can display itself.  */

- (void)setIgnoreShowAndHideCursor:(BOOL)this
	{
	ignoreShowAndHideCursor=this;
	}

// SndKit declares showCursor/hideCursor without a return type (1998
// SoundKit did too) and its implementations return self; match that.
- showCursor { 
	if (!ignoreShowAndHideCursor) [super showCursor];
	return self;
	}

- hideCursor { 
	// SndKit declares this without a return type and returns self.
	if (!ignoreShowAndHideCursor)
	// hideCursor is also subtly broken; it may or may not hide the 
	// cursor depending on its blink state.  I've tried changing the
	// selection to 0, but that does weird things to other soundviews.
	// I've also tried doing a [self display] after the [super hideCursor],
	// But that results in PostScript errors.  We may have to live with
	// this stupidity.  The other option is to never hide or never show
	// the blink-cursor (pick your poison).
		{
		[super hideCursor];
		}
	return self;
	}

- (id) retain // for debugging purposes
	{
	return [super retain]; 
	}

- (oneway void) release // for debugging purposes
	{
	[super release];
	}

@end


