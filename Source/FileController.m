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

  FileController.[h|m]
  Sean Luke
  
  The FileController is Resound's main controller object.  It handles document
  management, storage, foreign file reading, menu updating, inspector notification,
  printing, and a host of other functions.  While other objects have shrunk over 
  time, the FileController has slowly grown; I'm sorry about its size.

 s
  loading from foreign files.  One thing the category does is offer auto-conversion
  to a "safe" sound format; many PC sound files off the web are 11KHz, and a bug
  in the SoundKit causes these sounds to play accidentally at twice their speed (duh!).
 ug (yuck).  The Sound category also
  provides saving to sound files with auto-backup (in the form of ".~snd" extensions).
  It does not currently provide saving to foreign sound types (most of the foreign
  file reading was done through a present from Mmatime to expand it, sorry.  Should be easy though).  Most of the ResoundSound
  supporting code is in FileType.subproj.

  ResoundSound also handles the method for saving out a file.  This method allows for
  backups, and also has a hack in it to handle thes aren't conserved over simple SNDSoundStruct operations.  This
  results in *evil* bombs.  So Resound stores Info String information in the SoundView
  instead, loading it back into the sound only at save-time (hence ResoundSound's
  method mods).
  
  Thvate object, the Sound Table.  
  The Sound Table stores sound, soundview, and window IDs, and X/Y coordinates for 
  new windows. This is why you need to call the File Controller to find out what the 
  current sound, soundview, or window is.

  The FileController also he Pasteboard.
  Sounds perform Paste lazily; this means that if a sound has a cut/copy done on it,
  then is freed, then a paste is performed, the program bombs because the Pasteboard
  object is pointing to an invalid object.  NASTY!  The FileController d's Owner to nil when needed.  This used to be done
  through evil Objective-C hacking, but nowadays it just does a cut from a private
  text field which is guaranteed to exist.  When Resound is ported to OpenStep, this
  feature should be reworked.  Afterd
  as long as it needs it.

  ****************************************************************************/


//#define NOT_COMPILING_WITH_MODULES

#import "ConsoleManager.h"
#import "FileController.h"
#ifndef NOT_COMPILING_WITH_MODULES
#import "ModuleController.h"
#endif
#import "EditController.h" 
#import "PreferencesManager.h"
#import "InspectorManager.h"
#import "ResoundScrollView.h"
#import "ResoundMiscSoundView.h"
#import "SoundDocumentTable.h"
#import <AppKit/AppKit.h>
#import <SoundKit/SoundKit.h>
#import <Foundation/Foundation.h>
#import <string.h>
#import <stdio.h>
#import <sys/param.h>
#import <unistd.h>

// The legacy Jerome Genest file readers (FileType.subproj/*Reader.h)
// were dropped with the SndKit migration: SndKit's libsndfile readers
// handle the foreign formats now (see Source/Sound-ResoundSound.m and
// docs/RESOUND_SNDKIT_PLAN.md, Phase 1).

// DEFINES

#define CANCEL_ENABLED 1           /* These four are state information for the save windows */
#define CANCEL_DISABLED 0
#define CANCELLED 1
#define NOT_CANCELLED 0

#define INIT_WINDOW_FRAME_X_FROM_TOP_LEFT 0.0
#define INIT_WINDOW_FRAME_Y_FROM_TOP_LEFT 30.0
#define INIT_WINDOW_FRAME_WIDTH 600.0
#define INIT_WINDOW_FRAME_HEIGHT	250.0       /* Height, in pixels, of a new sound window */
#define MIN_WINDOW_FRAME_WIDTH	65.0        /* Minimum width, in pixels, of a sound window */
#define MIN_WINDOW_FRAME_HEIGHT  120.0        /* Minimum height, in pixels, of a sound window.
                                           this has to include the ruler and play mark! */

#define kFileTypes @"snd",@"au",@"aiff",@"wav",@"~snd",@"voc",@"iff",@"mp2"

extern double scroll_to_reduction (double scrollValue, double ratio);
/* In MiscSoundView */


/* Temporary for debugging -- Rhapsody has a weak-kneed gdb */
NSString* pString(NSString* p)
{
printf("###%s###\n",[p lossyCString]);
return p;
}


// The Sound (ResoundSound) category (initFromForeignSoundFile: and
// saveToSoundFile:sv:backup:) migrated to SndKit in its own file,
// Source/Sound-ResoundSound.m, with the SndKit port (see
// docs/RESOUND_SNDKIT_PLAN.md, Phase 1) - the legacy per-format
// readers it dispatched to were dropped in favour of SndKit's
// libsndfile-based readers.





@implementation FileController



/**** init
  Initializes the FileController.  Sets up the | cursor, default path, etc.
  */


- init
    {	
    NSImage* cursor_image;

    id returnval=[super init];
    
    NSPoint hot_spot;
    ignorethis=0;
    [NSBundle loadNibNamed: @"File.nib" owner:self];//loads Panels

    cursor_image=[[[NSImage alloc] initWithContentsOfFile:
        [[NSBundle mainBundle] pathForImageResource:@"SoundViewCursor"]] autorelease];
    hot_spot.x=7;hot_spot.y=7;
    // gets full path of SoundViewCursor
    if (cursor_image==nil) printf ("FileController ERROR:  Couldn't Find Cursor Image\n");
    soundViewCursor=[[NSCursor alloc]  initWithImage:cursor_image hotSpot:hot_spot];
    currentUntitledValue=0;
    defaultPath = [@"" retain];  // just to even out the retain/release messages
    soundTable = [[SoundDocumentTable alloc] init];
    return returnval;
    }


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [mainMenu setAutoenablesItems:NO];  /* better than put it in -init */

#ifndef NOT_COMPILING_WITH_MODULES
    [moduleController loadModules];
#endif
    [consoleManager prepareConsole];
}


- (void) dealloc
    {
    [defaultPath release];
    [soundTable release];
    [soundViewCursor release];
    [super dealloc];
    }




// CURRENT INFORMATION



/**** CurrentWindow:
  Returns the SoundView Window that is currently main, if any.
  */

- currentWindow:sender
    {
    NSWindow* win=[[soundTable find:[NSApp mainWindow]] window];
// it's possible that a window is still a valid current window,
// but due to an AppKit bug, NSApp doesn't know it until the next
// event cycle!  ARGH!  This happens
// usually when coming back from an application hide or a change
// to another application and back.  so currentWindow is a VERY
// short-lived set object which might be the current window if
// win isn't.
    if (win==nil && currentWindow!=nil)
    	win=[[soundTable find:currentWindow] window];
    return win;
    }


/**** CurrentSound:
  Returns the Sound in the SoundView Window that is currently main, if any.
  */
- currentSound:sender
    {
// hacked to call currentWindow so we can consolodate on the bug fix :-(
    return [[soundTable find:[self currentWindow:self]] sound];
    }



/**** CurrentSoundView:
  Returns the SoundView whose Window that is currently main, if any.
  */

- currentSoundView:sender
{
// hacked to call currentWindow so we can consolodate on the bug fix :-(
    return [[soundTable find:[self currentWindow:self]] soundView];
}



/**** SoundViewForSound:
  Returns the SoundView containing a particular Sound.  This is useful because
  Sounds don't store their containing SoundViews, but SoundViews store pointers
  to their contained Sounds.
  */
- soundViewForSound:sound
    {
    return [[soundTable find:sound] soundView];
    }





// SOUND ADJUSTMENT


/**** Soundchanged:
  SoundChanged is called by nearly everyone any time any modification
  to a sound is made.  It does several things:
  1)  It preserves the soundview's reduction factor, selection,
  and scroll position if possible while redisplaying the sound.
  A bug in NeXT's soundview code doesn't update display information
  unless the sound has been "set".
  2)  It updates the inspectors
  3)  It updates the modules
  */

- soundChanged:thisSound

    {	
    NSWindow* tempWindow;
    ResoundMiscSoundView*  tempSoundView;
    /*double reduction_factor;
    int first_sample,size;
    int scroll_sample;*/
    SoundDocument* doc;

    
    if ((doc=[soundTable find:thisSound]))
	{
        [doc setSoundChanged:YES];
        tempWindow=[doc window];
	[tempWindow setDocumentEdited:YES];
	tempSoundView=[doc soundView];
	
	[tempWindow disableFlushWindow];

	// we used to store and reset the selection information
	// here and immediately after setSound:.  But now we've
	// moved this to ResoundMiscSoundView's setSound:, which
	// works much better anyway (more general for everyone).

	//[tempSoundView setSound:thisSound];
	
	// Ask the *Window* to display itself -- this guarantees
	// (hopefully) that everything will be refreshed.  If you
	// just ask the SoundView to redisplay itself, if it for
	// some reason is smaller than it used to be, it may be 
	// smaller than the frame of the window and won't actually
	// erase the garbage to the right that used to be there when
	// it was larger.  Hopefully asking the window to display itself
	// fixes things.  
	[tempWindow display];
	[tempWindow enableFlushWindow];
	[tempWindow flushWindowIfNeeded];
	
	// update inspectors
	[(InspectorManager*)inspectorManager update];
#ifndef NOT_COMPILING_WITH_MODULES
	[(ModuleController*)moduleController update];
#endif
	}
    else printf ("FileManager ERROR:  Illegal Sound Edited\n");
    return self;
    }




/**** NewSound:for::
  Sets up the new sound for a given soundview, throwing away the old sound from
  the sound table.  Does not free the old sound, nor does it put the new sound
  *into* the soundview.  That's your responsibility.
  */

- newSound: thisSound for: thisSoundView: sender;
    {
    [[soundTable find:thisSoundView] setSound:thisSound];
    [self soundChanged: thisSound];
    return self;
    }



#ifdef NOT_COMPILING_WITH_MODULES
- getModuleController { return nil; }  /* messages can be sent to nil okay */
#else

/**** GetModuleController
  Returns the ModuleController.
  */

- getModuleController
    {
    return moduleController;
    }

#endif



/**** TurnOnMenu
  Turns on the menu.  This happens when a SoundView is selected, as opposed to a window
  some wayward module has created (modules are asked nicely to only create panels if they
  can).  A long time ago, the EditController's part of this used to turn on and off
  zooming, cut/copy/paste, etc.  But now all it does is turn on/off compacting.
  */

- turnOnMenu
    {
    [saveButton setEnabled:YES];
    [saveAsButton setEnabled:YES];
    [saveAllButton setEnabled:YES];
    [closeButton setEnabled:YES];
    [revertButton setEnabled:YES];
    [editController turnOnMenu:self];		// Should be set to not matter
    return self;
    }


/**** TurnOffMenu
  Turns off the menu.  This happens when a SoundView is deselected in favor of 
  some wayward module has created (modules are asked nicely to only create panels if they
  can).  A long time ago, the EditController's part of this used to turn on and off
  zooming, cut/copy/paste, etc.  But now all it does is turn on/off compacting.
  */

- turnOffMenu
    {
    [saveButton setEnabled:NO];
    [saveAsButton setEnabled:NO];
    [saveAllButton setEnabled:NO];
    [closeButton setEnabled:NO];
    [revertButton setEnabled:NO];
    [editController turnOffMenu:self];
    return self;
    }




/**** NewWindow:::
  Creates a new window, returning the window pointer, scroll view pointer, and sound view
  pointer.  There's some nasty bug fixes inside, so watch yer step.
  */

- newWindow:(NSWindow**) theWindowPointer:(ResoundScrollView**) theScrollViewPointer:(ResoundMiscSoundView**)theSoundViewPointer

    {
    /* Stolen right out of the NeXT Concepts 2.0, p. 9-33 */
    
    NSWindow* theWindow;	// this used to be just Window, until bug in NS 3.0 discovered.
    // see above...
    ResoundScrollView* theScrollView;
    ResoundMiscSoundView* theSoundView;
    unsigned int style_mask = 	NSClosableWindowMask|
				NSMiniaturizableWindowMask|
    				NSTitledWindowMask|
				NSResizableWindowMask;
    NSRect aRect, contentRect, scrollContentRect;
    NSSize min_size;
    min_size.width=MIN_WINDOW_FRAME_WIDTH;
    min_size.height=MIN_WINDOW_FRAME_HEIGHT;  /* should include the ruler! */
    
    [preferencesManager soundComingIn];

#define _MIN_(x,y) (x < y ? x : y)
#define _MAX_(x,y) (x > y ? x : y)

/* Figure a new window position */
    if ([self currentWindow:self]==nil)
        {
        aRect=[[NSScreen mainScreen] visibleFrame];
        aRect.origin.x=INIT_WINDOW_FRAME_X_FROM_TOP_LEFT;
        aRect.origin.y=aRect.size.height-INIT_WINDOW_FRAME_Y_FROM_TOP_LEFT;
	aRect.size.width=_MIN_(aRect.size.width,INIT_WINDOW_FRAME_WIDTH);
        aRect.size.height=_MIN_(aRect.size.height,INIT_WINDOW_FRAME_HEIGHT);
        aRect.size.width=_MAX_(aRect.size.width,MIN_WINDOW_FRAME_WIDTH);
        aRect.size.height=_MAX_(aRect.size.height,MIN_WINDOW_FRAME_HEIGHT);
        }
    else   // just below whoever's currently active, and same size as current
        {
        aRect=[[self currentWindow:self] frame];
	aRect.origin.y+=aRect.size.height;  /* set to top-left-point style */
        aRect.origin=[[self currentWindow:self] cascadeTopLeftFromPoint:
		aRect.origin]; /* is there a good reason this isn't a factory method? */
	aRect.origin.y-=aRect.size.height;  /* reset to ordinary origin format */
        }
	 
	contentRect=[NSWindow contentRectForFrameRect:aRect styleMask:style_mask];

	scrollContentRect.size=[NSScrollView contentSizeForFrameSize:contentRect.size
               hasHorizontalScroller:YES
                hasVerticalScroller:NO
                  borderType:NSNoBorder];
	scrollContentRect.origin.x=0;
	scrollContentRect.origin.y=0;

   theWindow=[[[NSWindow alloc] initWithContentRect:contentRect    // see above...
	     styleMask:style_mask
              backing:NSBackingStoreBuffered
		defer:NO] autorelease];

	// By default windows are sent a *release* message when they are closed.  This
	// was rather poor thinking on NeXT's part IMHO, because it violates the retain/release
	// guarantee (you're responsible for releasing anything you've allocated).
	// I'd rather have the guarantee in force, so after autoreleasing the window, I
	// tell it not to do its stupid default behavior:

	[theWindow setReleasedWhenClosed:NO];

	// Now create the other objects...

    theScrollView=[[[ResoundScrollView alloc] initWithFrame:contentRect] autorelease];			// not ScrollView, note...
    theSoundView = [[[ResoundMiscSoundView alloc] initWithFrame:scrollContentRect] autorelease];	// my custom sound view.

/* A bug in the SoundView object causes exceptions to be raised when you
create more than one soundview because it tries to make sure the blinking
sound cursor line is only in one soundview and it doesn't have a nice way
to do it like NSTextView.  So when you set the document view below,
it tries to draw the cursor (or hide it, I'm not sure), but the SoundView's
not part of a window yet, so things freak out.  This is really dumb. 
So I just catch the exception and go on my merry way.  Seems to be okay. */
	[theSoundView setIgnoreShowAndHideCursor:YES];
	[theWindow setContentView:theScrollView];
	[theScrollView setDocumentView:theSoundView];
	[theSoundView setIgnoreShowAndHideCursor:NO];

/* Tweak Window */

    [theWindow setBackgroundColor:[NSColor whiteColor]];
    [theWindow setMinSize:min_size];
    [theWindow setMiniwindowImage: [[[NSImage alloc] initWithContentsOfFile:
       [[NSBundle mainBundle] pathForImageResource:@"Miniaturize"]] autorelease]];
    [theWindow useOptimizedDrawing:YES];
    [theWindow resetCursorRects];

/* I'm *assuming* the MiscSoundView sets up the ruler on its own! */

/* Tweak ScrollView */

    [theScrollView setHasVerticalScroller:NO];
    [theScrollView setHasHorizontalScroller:YES];
    [theScrollView setAutoresizesSubviews:YES];
    [theScrollView setAutoresizingMask:NSViewHeightSizable|NSViewWidthSizable];
    [theScrollView setSelectionManager: selectionInspector];


/* Tweak SoundView */
    if (soundViewCursor==nil) printf ("FileManager ERROR:  Empty Cursor\n");
    [theSoundView setCursor:soundViewCursor];
    [theSoundView setSelectionManager: selectionInspector];
    [theSoundView setContinuousUpdate: YES];  // For Continuous Sample Update
    [theSoundView setPostsFrameChangedNotifications:YES];					
    [theSoundView setAutoresizingMask:NSViewHeightSizable]; // but this doesn't work!!
    [theSoundView setDisplayMode:[preferencesManager minMaxDisplay]];	

	// lastly, reset the ruler bounds settings.  I believe this is necessary
	// for the new MiscSoundViews.
	[theSoundView adjustBounds:self];

    // Preferences
    
    [theSoundView update:
     [preferencesManager displayTicks]:
     [preferencesManager displayAmplitude]:
   YES:
     [preferencesManager displayZeroLine]:
   UPDATESOUNDVIEW_XAXIS_DISPLAY_FORMAT_TICKS:
     [preferencesManager majorTickValue]:
     [preferencesManager minorTickValue]:
     [preferencesManager minorTickFormat]:
     [preferencesManager amplitudeFormat]:
     [preferencesManager scrollToReflectSound]];

/* Set up delegates */

    [theSoundView setDelegate:soundManager];
[theWindow setDelegate:self];

    /* BEGIN BUG FIX
       The bug that causes Resound to bomb on creating a new window is caused here...
       Note that the result is that drawMinMax or whatnot tries reading sound data that doesn't exist.
       I suspect this is because of inadequate checking in the SoundView, and a resultant assumption that
       the data is in a different place than it actually is... */
    
//    thisSize=[[theWindow contentView] frame].size; // just in case theWindow's contentView is
/* Don't think we need this anymore 
    // different from theScrollView...
    thisRect=[theSoundView bounds];
    // now modify the height based on whether or not you're drawing a ruler
    a= ([theSoundView xAxisDisplayed] ? MISCSOUNDVIEW_RULER_HEIGHT+
	MISCSOUNDVIEW_PLAY_MARK_HEIGHT : 0);
    [theSoundView sizeTo: thisRect.size.width : thisSize.height-a];
*/    
    
    /* END BUG FIX */
    
    *theWindowPointer=theWindow;
    *theScrollViewPointer=theScrollView;
    *theSoundViewPointer=theSoundView;
    return self;
    }









// NEW SOUNDS







/**** NewSound:::
  For a given sound, creates and returns a new window, soundview, and scrollview.
  Like NewWindow, this also has its own batch of unique bug-fixes for NeXT's bag of
  SoundKit bugs, so watch yer step.
  */


- (SoundDocument*) newSound: (Sound*) sound:(BOOL) untitled:(NSString*)filename
/* Sets up a new window for sound.  Adds everything necessary to the
sound table.  Returns the new SoundDocument object.  If filename is nil,
it's assumed to be @"" (don't do this please).  If sound is nil, a new sound
is created (also, don't do this please).

This method assumes the info string needs to be loaded.  Usually the info
string should be "\0" anyway, except when loading sound files.
*/
{	
	ResoundMiscSoundView* sndv;
	ResoundScrollView* scrv;
	NSWindow* win;
	SoundDocument* doc;
	
	if (filename==nil) filename=@"";
	if (sound==nil) sound=[[[Sound alloc] init] autorelease];

	[self newWindow:&win:&scrv:&sndv];

        /* fix the info string bug in the SoundKit (dang) */
        [sndv loadInfo:sound];  // this safe from a nil info string
        if ([sound info]!=NULL)  // assume it's a char array of size at least 1!
	   ((char*)[sound info])[0]='\0';
        /* done fix */

        doc=[soundTable newDocument:sound:sndv:win:filename:untitled];
        if ([doc untitledValue]==SOUNDDOCUMENT_TITLED)
            [win setTitleWithRepresentedFilename:[doc filename]];
        else [win setTitle:[doc title]];

        [win setDocumentEdited:[doc soundChanged]];
        [sndv setSound:sound];// a known bug in 3.x states that setSound will automatically reset
// the reduction factor of any sound, so only *after* any setSound call, we must
// set the reduction factor of the sound if we want our own reduction factor.
// see NeXTAnswers 1451.
// This is alleviated now in the setSound method of ResoundMiscSoundView.
// But the code below is still relevant.

        if ([preferencesManager zoomIn])
            [sndv setReductionFactor: scroll_to_reduction
            (0,(double)[sound sampleCount]/(double)([scrv contentSize].width))];
        else
            [sndv setReductionFactor: scroll_to_reduction
            (1,(double)[sound sampleCount]/(double)([scrv contentSize].width))];


	// now show that sucker

        [win makeKeyAndOrderFront:self];
	
	// let the inspectors know there's a new sound now.  This may
	// generate two updates (windowDidChange also generates an update).
	// We may want to fix this later.

	[self update];
	return doc;
}


/**** NewFromPasteBoard:
  Creates a new Resound Sound and window from whatever's currently on the Pasteboard.
  Called from a menu item.
  */


- newSoundFromPasteBoard:sender
    {
    Sound* newSound=[[[Sound alloc] init] autorelease];
    SoundDocument* sd;
    NSMutableArray* array=[NSMutableArray arrayWithCapacity:1];

    id pb=[NSPasteboard generalPasteboard];
    [array addObject:NXSoundPboardType];

    if (![[pb availableTypeFromArray:array] isEqualToString:NXSoundPboardType])
	{
	NSRunAlertPanel(@"Pasteboard",
			@"The pasteboard is empty.",@"Okay",nil,nil);
	return nil;
	}
#ifdef PASTE_BUG
    else if (![self stillExists:(void*)[pb owner]])
	    {
	    [self invalidatePasteboard];
	
	    NSRunAlertPanel(@"Pasteboard",
	                    @"The pasteboard is empty.",@"Okay",nil,nil);
	    return nil;
	    }
#endif

    sd=[self newSound:newSound:YES:@""];
    [[sd soundView] readSelectionFromPasteboard:
	[NSPasteboard generalPasteboard]];
	// Now the zooming is invalid, so I need to re-zoom!

	{
	SoundDocument* doc=[soundTable find:sd];
	 if ([preferencesManager zoomIn])
   	 [[doc soundView] setReductionFactor: scroll_to_reduction
   	     (0,(double)[[doc sound] sampleCount]/(double)([[[doc window] contentView] contentSize].width))];
   	 else
         [[doc soundView] setReductionFactor: scroll_to_reduction
   	     (1,(double)[[doc sound] sampleCount]/(double)([[[doc window] contentView] contentSize].width))];
   	 [self update];
	}

    return self;
    }



/**** NewFromMicrophone:
  Begins recording.  Called from a menu item.
  */

- newSoundFromMicrophone:sender
    {
    [consoleManager showConsole:self];  /* So we can see what's going on */
    return [consoleManager recordDown:self];
    }




/**** NewRecordedSound:
  Given a freshly-recorded sound, sets up an "Untitled" window for it.
  */

- newRecordedSound:thisSound
    {
    [self newSound:thisSound:YES:@""];

    return self;
    }




// OPENING SOUNDS




/**** Open::
  Opens a sound.  Note that the InfoString bug bites here, so it's been hacked so
  that the InfoString is loaded into the SoundView at open-time.  Updates inspectors,
  sets up defaults, you name it.  By the way, right now Resound refuses to "open"
  new modules on-the-fly, that is, after the program has loaded.  This is probably
  a needless restriction, and it would be well worth it to allow loading at any time.
  */

- open:(NSString*)nameoffile:(BOOL)fromPanel:sender
    {	
    Sound* theSound;

    NSString* extension=[nameoffile pathExtension];
    SoundDocument* doc;
    
    if ([extension caseInsensitiveCompare:@"rmod"]==NSOrderedSame) 
	{
	NSRunAlertPanel(@"Modules",@"Resound cannot load modules on-the-fly.",@"Oops",nil,nil);
	return self;
	}

    if ((doc=[soundTable findFilename:nameoffile])!=nil)
	{
	[[doc window] makeKeyAndOrderFront:self];
	return self;
	}

     //...else, it's a new sound to open.	
    theSound = [[[Sound alloc] initFromForeignSoundFile:nameoffile:	
		[preferencesManager convertOnOpen]] autorelease];

    if ([extension caseInsensitiveCompare:@"snd"]==NSOrderedSame)
	[self newSound:theSound:NO:nameoffile];
    else
    	[self newSound:theSound:YES:nameoffile];
    
    // Lastly, do we play the sound on open?
    // We only play files if the user asked and they weren't opened
    // with the open panel.
    
    if (!fromPanel&&[preferencesManager playOnOpen])
	[consoleManager playDown:self];

    return self;
    }





/**** Open:
  Loads the Open panel, opening the sound if valid.  Called from a menu item.
  */


- open:sender
    {
    id openpanel;
    int result;
    NSString* nameoffile;
    NSArray* filetype = [NSArray arrayWithObjects:kFileTypes,nil];
    
    openpanel=[NSOpenPanel openPanel];
    [openpanel setAllowsMultipleSelection:NO];
    
    result=[openpanel runModalForDirectory:NSHomeDirectory() file:nil types:filetype];
    
    if (result==NSOKButton)
        {
        [defaultPath release];
        defaultPath = [[openpanel directory] copy];
        nameoffile = [openpanel filename];
        [self open:nameoffile:YES:self];
        }
    return self;
    }





// SAVING PROCEDURES		




/**** SaveAs
  Performs a "SaveAs..." operation, including handling the panel and everything.
  Returns CANCELLED if the user cancelled the operation, else NOT_CANCELLED.
  */

- (int) saveAs
    {
    NSString* nameoffile;
    id savepanel;

    SoundDocument* doc;

    if ((doc=[soundTable find:[self currentWindow:self]])!=nil)
	{
	if ([[doc sound] isEmpty])
	    {
        NSRunAlertPanel(@"No Data",@"This sound cannot be saved because it has no data", @"Oh",nil,nil);
	    [doc setSoundChanged:NO];
	    [[doc window] setDocumentEdited:NO];
	    }
	else
	    {
	    NSString* fn=[doc filename];
	    NSString* saveDirectory;
        NSString* saveFile;
        int result;
	    if ([doc untitledValue]==SOUNDDOCUMENT_TITLED)
		{
            saveDirectory=[fn stringByDeletingPathExtension];
            saveFile=[fn lastPathComponent];
		}
	    else
		{
            saveDirectory=defaultPath;
            saveFile=@"";
		}
	    
	    savepanel=[NSSavePanel savePanel];
	    
	    [savepanel setRequiredFileType:@"snd"];
	    result=[savepanel runModalForDirectory: saveDirectory file: saveFile];
	    if (result==NSOKButton)
		{
            [defaultPath release];
            defaultPath = [[savepanel directory] copy];
            nameoffile = [savepanel filename];

		[[doc sound] saveToSoundFile:nameoffile:
		 [doc soundView]:
		 [preferencesManager backup]];
        [[doc window] setTitleWithRepresentedFilename:nameoffile];
		[[doc window] setDocumentEdited:NO];
		[doc documentWasSaved:nameoffile];
		return NOT_CANCELLED;
		}
	    else
		{
		return CANCELLED;
		}
	    }
	}
    return NOT_CANCELLED;
    }


/**** Save
  Performs a "Save..." operation.   If the sound is untitled, this method
  calls and returns the value of -SaveAs.  Otherwise, it teturns NOT_CANCELLED always.
  */


- (int) save				// returns cancelled or not cancelled
{
    SoundDocument* doc;

    if ((doc=[soundTable find:[self currentWindow:self]])!=nil)
	{

	if ([doc soundChanged])
	    {
	    if ([doc untitledValue]!=SOUNDDOCUMENT_TITLED)				// is sound untitled?
		{
		return [self saveAs];
		}
	    else
		{
		if ([[doc sound] isEmpty])
		    {
            NSRunAlertPanel(@"No Data",@"This sound cannot be saved because it has no data", @"Oh",nil,nil);
		    [doc setSoundChanged:NO];
		    [[doc window] setDocumentEdited:NO];
		    }
		else
		    {
		    [[doc sound] saveToSoundFile:[doc filename]:[doc soundView]:[preferencesManager backup]];
            [doc documentWasSaved:[doc filename]];
            [[doc window] setDocumentEdited:NO];
		    }
		}
	    }
	}
    return NOT_CANCELLED;
    }




/**** SaveLoop:
  Goes into the save-loop when an application is quitting.  If may_cancel is true, then
  the application returns CANCELLED if the user cancels at any SaveAs panel or at any
  dialog asking if he wants to save a file, else it returns NOT_CANCELLED.  If may_cancel
  is false, this method doesn't permit the user to cancel.  Right now it doesn't look like
  the method informs the user that he can't cancel; it just re-posts the save panels.
  However, this only occurs when the machine is powering down.

  This SaveLoop has some problems.  First, without any warning, it saves *all* sounds 
  that can be saved without a saveAs window.  Second, it gives no "can't be cancelled"
  warnings.

  The proper way to do this would be to first ask if you want to save everything, then
  for each item, ask if you want to save that particular item.  This was a hack; a better
  state machine should be set up.
  */

- (int) saveLoop: (int) may_cancel
{
    id anObject;
    NSEnumerator *en=[soundTable objectEnumerator];
    while((anObject = [en nextObject]))
        {
        NSString* saveRequest;
        int result;
        int local_cancel=1;

        while(local_cancel)
            {
            saveRequest=[NSString stringWithFormat: @"Save %@?",
                [anObject simpleTitle]];
            local_cancel=0;
            [[anObject window] makeKeyAndOrderFront:self];

            if (may_cancel)
                result=NSRunAlertPanel(@"Saving...",saveRequest,
                                       @"Save",@"Don't Save",@"Cancel");
            else
                result=NSRunAlertPanel(@"Saving...",saveRequest,
                                       @"Save",@"Don't Save",nil);
            if (result==NSAlertDefaultReturn)    // save
                {
                    local_cancel=[self save];
                }
            else if (result==NSAlertAlternateReturn)  // don't save
                {
                /* Do nothing */
                }
            else         // cancelled!
                {
                return 1;
                }
            }
        }
    return 0;  // didn't cancel.
}

// SAVING MENU METHODS	




/**** SaveAll:
  Saves all the sounds.  Supposedly.  (See SaveLoop:)
  Called from a menu item.
  */


- saveAll:sender
    {
    if ([soundTable changedSoundExists]) [self saveLoop:CANCEL_ENABLED];
    return self;
    }


/**** Save:
  Saves a sound, possibly doing a SaveAs.  Called from a menu item.
  */

- save:sender
    {
    [self save];
    return self;
    }


/**** SaveAs:
  Does a SaveAs on a sound.  Called from a menu item.
  */

- saveAs:sender
    {
    [self saveAs];
    return self;
    }




//  REVERT


/**** Revert:
  Reverts to a previously-saved version of the sound.  Called from a menu item.
  This is a relatively untested method, by the way.
  */


- revert:sender
    {
    SoundDocument* doc;

    if ((doc=[soundTable find:[self currentWindow:self]])!=nil)
	{
	if ([doc soundChanged])
	    {
	    if ([doc untitledValue]!=SOUNDDOCUMENT_TITLED)				// is sound untitled?
		{
		// SOUND IS UNTITLED
		NSRunAlertPanel(@"Revert",@"This sound is untitled and cannot be reverted.",@"Okay",nil,nil);
		}
	    else
		{
		int answer=NSRunAlertPanel(@"Revert",@"Revert to saved sound?",@"Okay",@"Cancel",nil);
		if (answer==NSAlertDefaultReturn)
		    {
            /* this isn't the prettiest way to do a revert (creating a new window, yuck),
               but it's certainly the safest. */
		    id win;
		    NSString* s=[[[doc filename] retain] autorelease];
		    [consoleManager stopDown:self];
		    win=[doc window];
		    ignorethis=1;
		    [win performClose:self];
		    ignorethis=0;
            	    [soundTable remove:doc];
		    [self open:s:YES:self];
		    }
		}
	    }	
	else
	    {
	    // SOUND DOESN'T NEED REVERTING
	    NSRunAlertPanel(@"Revert",@"This sound has not been changed since last save.",@"Okay",nil,nil);
	    }
	}
    else
	{
	// NO SOUND TO SAVE
	NSRunAlertPanel(@"Revert",@"There's no sound to revert.",@"Okay",nil,nil);
	}
    return self;
    }





// QUIT



/**** Quit:
  Called when the user wants to quit.
  Possibly quits the program.  Runs a SaveLoop first (cancellable).
  */

- quit:sender	// user wants to terminate
{
   [NSApp terminate:self];
   return self;
}


/**** quitAbsolutely
  Terminates the program.  Runs a SaveLoop, but doesn't permit the user to cancel it.
  This currently is unused; it's appropriate for NeXTSTEP, but less so for OPENSTEP.
  */


- (void) quitAbsolutely			// Application must terminate
    {
    if ([soundTable changedSoundExists])
        {
        int answer=
        NSRunAlertPanel(@"Must Quit",@"Resound must quit.\n  Save before quitting?",@"Save",@"Don't Save",nil);

        if (answer==NSAlertDefaultReturn)
		{
        	[self saveLoop:CANCEL_DISABLED];
        	}
	}
    }





    // CLOSE WINDOW


    /**** Close:
      Closes a window.  Used to be a menu option; now a legacy item mostly (closing is
      in 3.x properly done in the Windows menu).
      */

- close:sender
    {
    SoundDocument* doc;
    if ((doc=[soundTable find:[self currentWindow:self]])!=nil)
	{
	[[doc window] performClose:self];
	}
    return self;
}


/**** CloseWindow
      Closes a window, but checks first if it's unsaved and asks the user if he wants
      to save.  The user can then save, not save, or cancel the close.
      */


- (int) closeWindow							//  Returns 0 if window shouldn't be closed
    {
    id sv;
    id windowtoclose;
    SoundDocument* doc;

    if ((doc=[soundTable find:[self currentWindow:self]])!=nil)
	{
	shouldCloseWindow=0;
	windowtoclose=[doc window];
	sv=[doc soundView];
	
	if ([doc soundChanged])
	    {
	    int answer;
	    answer=NSRunAlertPanel(@"Close",@"Save before closing?",@"Save",@"Don't Save",@"Cancel");
	    if (answer==NSAlertDefaultReturn)
		{
            	if ([self save]==CANCELLED) shouldCloseWindow=0;
            	else shouldCloseWindow=1;
		}
	    else if (answer==NSAlertAlternateReturn) shouldCloseWindow=1;
	    else /*if (answer==NSAlertOtherReturn)*/ shouldCloseWindow=0;

	    if (shouldCloseWindow)
		{
#ifdef PASTE_BUG
		// First, invalidate pasteboard
		
		id pb=[NSPasteboard generalPasteboard];
		if (sv==[pb owner])
		    {
		    [self invalidatePasteboard];
		    }
#endif
		// delete and close files
		[consoleManager stopDown:self];
        	[soundTable remove:doc];
		return 1;		// WILL THIS WORK?
		}
	    }
	else
	    {
#ifdef PASTE_BUG
	    // First, invalidate pasteboard
	    
	    id pb=[NSPasteboard generalPasteboard];
	    if (sv==[pb owner])
		{
		[self invalidatePasteboard];
		}
#endif	    
	    [consoleManager stopDown:self];
	    [soundTable remove:doc];
	    return 1;			// WILL THIS WORK?
	    }
	}
    return 0;
    }	




// PRINT




/**** Print:
  Prints the visible contents of the current sound.  Called from a menu item
  */


- print:sender
    {
    SoundDocument* doc;
    if ((doc=[soundTable find:[self currentWindow:self]])!=nil)
    {
	[[[[[self currentWindow:self] contentView] documentView] superview] print:self];
	}
    return self;
    }

/**** DoPageLayout:
Runs the Page Layout panel.  Called from a menu item.
*/

- doPageLayout:sender
{
[NSApp runPageLayout:self];
return self;
}


// WINDOW MANIPULATION





/**** Update:
  Updates inspectors after a window has changed or the current window has become
  something else.
  */

- update
    {
    SoundDocument* doc;
    if ((doc=[soundTable find:[self currentWindow:self]])!=nil)
	{
	[self turnOnMenu];
	[inspectorManager turnOnInspector];
	[(InspectorManager*)inspectorManager update];
#ifndef NOT_COMPILING_WITH_MODULES
	[(ModuleController*)moduleController update];
#endif
	}
    else
	{
	[self turnOffMenu];
	[(InspectorManager*)inspectorManager turnOffInspector];
#ifndef NOT_COMPILING_WITH_MODULES
	[(ModuleController*)moduleController update];
#endif
	}
    return self;
    }



/**** moduleWindowDidBecomeMain
  Called after a module kindly informs us that (1) he's using a window instead of a panel,
  and (2) that window just became main.  This gives us a chance to turn off our menus,
  set our inspectors to blank, etc.
  */


- moduleWindowDidBecomeMain
    {
    [self update];
    return self;
    }




/**** setPlaying::
  Set a window title foo to be "PLAYING: foo".  Or not.  Depends on to_this.
  */

- setPlaying:(NSWindow*) win:(BOOL) to_this
    {
    NSString* tmpname;
    if (to_this)
      {
        tmpname=[NSString stringWithFormat:@"PLAYING: %@",[win title]];
        [win setTitle:tmpname];
      }
    else
      {
        SoundDocument* doc=[soundTable find:win];
        if ([doc untitledValue]==SOUNDDOCUMENT_TITLED)
            [win setTitleWithRepresentedFilename:[doc filename]];
        else [win setTitle:[doc title]];
      }
    return self;
    }






// BUGS IN PASTE FACILITY


/**** stillExists::
  Returns true if pointer still exists in Resound's sound table.
  */
#ifdef PASTE_BUG
- (BOOL) stillExists:(void*) pointer
    {
    return ([soundTable find:(id)pointer]!=nil);
    }


/**** invalidatePasteboard
  Eliminates any sound posted on the pasteboard.
  */

- invalidatePasteboard
    {
    /* First, invalidate the old data */
    [[NSPasteboard generalPasteboard] changeOwner:NULL];  // muzzle it
    [(NSText*)junkField cut:self];  /* is now an NSText object, not an NSTextField!!!!! */
    return self;
    }
#endif





// METHODS IMPLEMENTED AS A WINDOW DELEGATE


    /**** windowDidResize:
      Handles ruler changes with a window resize.
      */

- (void)windowDidResize:sender
        {
    /*  With new MiscSoundView, no longer needed.

    NSSize thisSize;
        NSRect thisRect;
        id soundView;
    int a;
    SoundDocument* doc;

        [(InspectorManager*)inspectorManager update];
        doc=[soundTable find:sender];
        thisSize=[[[doc window] contentView] contentSize];
        soundView=[doc soundView];
	thisRect=[soundView bounds];
	// now modify the height based on whether or not you're drawing a ruler
	a= ([soundView xAxisDisplayed] ? MISCSOUNDVIEW_RULER_HEIGHT +
	    MISCSOUNDVIEW_PLAY_MARK_HEIGHT : 0);
	[soundView sizeTo: thisRect.size.width : thisSize.height-a];
	*/
    }




/**** windowDidBecomeKey:
  Updates the inspectors and turns on the menu if appropriate.
  */

- (void) windowDidBecomeKey:sender
    {
	currentWindow=[sender object];
	[self update];
	currentWindow=nil;
    }


/**** windowDidBecomeMain:
     Updates the inspectors and turns on the menu if appropriate.
     */

- (void) windowDidBecomeMain:sender
    {
        currentWindow=[sender object];
        [self update];
        currentWindow=nil;
    }



/**** windowWillClose:
  Checks first if the user wants to save (if appropriate) or cancel the close
  operation.  If so, does what's necessary to save or cancel.
  */

- (BOOL)windowShouldClose:sender
    {
    if (ignorethis) return YES;
	[sender makeKeyAndOrderFront:self];
	if (![self closeWindow]) 
	    {
	    return NO;			// don't close it!
	    }
	else 
	    {
	    // Next do some updating.	
	    
	    if ([soundTable empty])
		{
		[self update];
		}
	    }
    return YES;
    }


- (void)windowDidMiniaturize:sender
    {
	[self update];  /* the only windows for which I am a delegate
			   are the MiscSoundView windows */
    }


    // METHODS IMPLEMENTED AS A DELEGATE OF APPLICATION


    /**** appDidInit:
      Load the modules and set up the console.
      */


- appDidInit:sender
    {
#ifndef NOT_COMPILING_WITH_MODULES
    [moduleController loadModules];
#endif
    [consoleManager prepareConsole];

    return self;
    }

/**** appAcceptsAnotherFile:
     Called during drag-and-drop onto the application tile.  "Sure, we'll try opening anything you give us!"
     */

- (BOOL)appAcceptsAnotherFile:sender
   {
   return YES;
   }


/**** app:openFile:type:
  Called during drag-and-drop onto the application tile.  Attempts to open the file.
  */

- (BOOL) application:(NSApplication*)sender openFile:(NSString*)filename
    {
    [self open:filename:NO:self];
    return YES;
    }


/**** applicationShouldTerminate:
Requests to terminate the program.  The user can save files and can cancel
the termination.
*/

- (BOOL)applicationShouldTerminate:(NSApplication *)sender
{
if ([soundTable changedSoundExists])
{	
int answer=NSRunAlertPanel(@"Quit",@"Save before quitting?",@"Save",
                @"Don't Save",@"Cancel");
if (answer==NSAlertDefaultReturn)
    // save first
    {
    if ([self saveLoop:CANCEL_ENABLED]==CANCELLED) return NO;
            else return YES;
    }
else if (answer==NSAlertAlternateReturn)
    // don't bother saving, just quit
    return YES;
else  // (answer==NSAlertOtherReturn)
    // don't quit
    return NO;
}
else return YES;
}



@end