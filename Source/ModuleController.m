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

  ModuleController.[h|m]
  Sean Luke
  
  The ModuleController loads and provides an interface to Resound's modules.
  The ModuleProtocol api has changed over the years; the ModuleController tries
  to be as backward-compatible with legacy methods as it can.  This api can change
  totally in the OpenStep version, as the NXBundle object has changed a lot and
  so old modules may need some conversion to make the change over to OpenStep
  anyway.

  The ModuleController expects each module to subclass from Module; this gives
  the ModuleController the api it needs to communicate with the module.  Modules
  in turn communicate with the ModuleProtocol api, which the ModuleController 
  adheres to.

  When loading a module, the ModuleController grabs the module's ModuleMenuNode
  tree and uses the tree to set up the Module's menus.  It also grabs (if any)
  the Module's help text and sets up a menu to display this as well.  Then it
  sets itself as the controller object in the Module, and does some cleanup.

  To locate modules, the ModuleController uses an old NeXT-provided object, the
  PAStringList.  OpenStep provides much of the file-name functionality that
  PAStringList used to provide, so this object can go away after conversion.
  
  ****************************************************************************/


#import "ModuleController.h"
#import "ResoundNibs.h"
#import "FileController.h"
#import "SoundManager.h"
#import "ZoomInspector.h"
#import "AttributesInspector.h"
#import "SelectionInspector.h"
#import "Module.h"
#import "ModuleMenuNode.h"
#import "ResoundMiscSoundView.h"

#import <stdio.h>
#import <AppKit/AppKit.h>

@implementation ModuleController


/**** init
  Initializes the ModuleConroller.  Loads its nib sections and prepares it
  for loading modules.
*/

- init
    {
    id returnVal=[super init];
    /* Load Module Help Window */
    [ResoundNibs loadNibNamed: @"Module" owner:self];


    loaded=0; //windowsLoaded
    goAhead=NO;

    windowsLoaded=1;		// an artifact.
    modules=[[NSMutableArray alloc] init];  // ...or whatever
    numhelp=0;
    helpnames=[[NSMutableArray alloc] init];
    helpfiles=[[NSMutableArray alloc] init];
    return returnVal;
    }



/**** dealloc
  Frees the ModuleController.  Also frees all help text files and name strings, and
  frees all modules.
*/


- (void) dealloc
    {
    [modules release];
    [helpnames release];
    [helpfiles release];

    [super dealloc];
    }




/**** LoadModules
  Loads all modules.  Locates them, sets up their menu trees, loads their help text
  information, loads and allocates their chief object and sets the ModuleController
  as their gateway.
*/

- loadModules
    {	
    BOOL isDir= NO;

    NSString *file,*path;
    NSArray *tempPathsArray;						// Holds the StandardLibrary paths
    NSMutableArray *pathsArray= [[NSMutableArray alloc] init];		// Holds the StandardLibrary paths with "/Resound" appended + the path of the dir of the app
    NSMutableArray *enumeratorsArray = [[NSMutableArray alloc] init];  // Holds the enumerator for each path (all files containes in each existing path)
    NSMutableArray *keptPathsArray = [[NSMutableArray alloc] init];     // Holds the the existing paths from pathsArray in the same order than files in enumeratorsArray 
   
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSEnumerator *enumerator,*keptPathsEnumerator;			// Enumerator used to iterate throught all the paths and all the files of each path
    NSDirectoryEnumerator *dirEnum = nil;

    //tempPathsArray = (NSMutableArray*)NSStandardLibraryPaths();		// get the standard libs paths

    tempPathsArray = (NSMutableArray*)NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSAllDomainsMask,TRUE);  // This is the suggested call for DR2

    enumerator = [tempPathsArray objectEnumerator];

    while (path = [enumerator nextObject])
        [pathsArray addObject: [path stringByAppendingPathComponent:@"Resound"]];		// Add /Resound to each standard lib path

    // this is incorrect!
    //[pathsArray addObject:[ [[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent]];  //Add the app directory to the path we must search
    [pathsArray addObject:[[NSBundle mainBundle] bundlePath]];  

    enumerator = [pathsArray objectEnumerator];
	
    while(path = [enumerator nextObject])
    	if ([fileMgr fileExistsAtPath:path isDirectory:&isDir] && isDir)	// We will only with existing paths (NSStandardLibraryPaths() may return
        {									// "generic paths" not existing on our system 
        	[enumeratorsArray addObject: [fileMgr enumeratorAtPath:path]];		// Retreiving all files for each existing path via an enumerator
		[keptPathsArray addObject:path];				// Keeping track of the existing paths in the same order
		}

    [loadPanel center];
    [loadPanel makeKeyAndOrderFront:self];

        if (!loaded)
        {
        enumerator = [enumeratorsArray objectEnumerator];
        keptPathsEnumerator = [keptPathsArray objectEnumerator];

        while(dirEnum = [enumerator nextObject])			/* Enumerate over all paths: App Wrapper, ~Library/Resound, Local/Library/Resound */
		{
       		path = [keptPathsEnumerator nextObject];
        	if(dirEnum)
        		while (file = [dirEnum nextObject]) 		// Enumerate over all the files for each path
				{
        			if ([[file pathExtension] isEqualToString:@"rmod"])
					{
                                	[self loadAModule:[path stringByAppendingPathComponent:file]];	// found a module, load it
					}
				}
		}


	[loadPanel close];
	[[NSApp mainMenu] update];
	loaded=1;
	}

    [pathsArray release];
    [enumeratorsArray release];
    [keptPathsArray release];
    return self;
    }

- (void) loadAModule: (NSString *)file
{
NSBundle *mybundle;
id tempinstance;
id menu_node;
NSString *helpResource=nil;
NSMenu   *moduleMenu = [[[NSApp mainMenu] itemWithTitle:@"Modules"]submenu];

if ([moduleMenu itemWithTitle:[[file lastPathComponent] stringByDeletingPathExtension]]) // Module already loaded ?
	{
	NSString *tempString = @"Trying to load \"";
	
	[tempString autorelease];
        tempString = [tempString stringByAppendingString:file];
        tempString = [tempString stringByAppendingString:@"\" but there is already a loaded module with this name, make sure you are using the latest version"];
	NSRunAlertPanel(@"Module loaded", tempString, @"Okay", 0, 0);
	return;
	}
[loadPanel disableFlushWindow];
[fileName setStringValue:[[file lastPathComponent] stringByDeletingPathExtension]];
[pathName setStringValue:file];
[loadPanel enableFlushWindow];
[loadPanel flushWindowIfNeeded];
[loadPanel display];
PSWait();
mybundle = [[NSBundle alloc] initWithPath:file];
tempinstance=[[[mybundle principalClass] alloc] init];
[tempinstance setModuleControllerTo: self];
[modules addObject:tempinstance];
menu_node=[tempinstance getModuleMenuNode];
[self generateMenu: menu_node: [[[NSApp mainMenu] itemWithTitle:@"Modules"]submenu] ];

// Add Help Menu if appropriate
helpResource = [mybundle pathForResource:@"ModuleInfo" ofType:@"rtfd"];

if (helpResource)
[self generateHelpMenu:helpResource:[[file lastPathComponent] stringByDeletingPathExtension]:[[[[[NSApp mainMenu] itemAtIndex:0] submenu]itemWithTitle:@"Module Info"] submenu]];

}


- (void) _junkSelector:sender { return; }
        // to create a valid selector, just in case


/**** GenerateMenu::
  Recursively sets up the menu tree based on the module's provided ModuleMenuNode tree.
*/


- generateMenu:this_node:this_menu
    {
    int x;
    int length=[this_node numSubmenus];
    id submenu;
    id tempmenu;
    //id xmenu;
    for (x=0;x<length;x++)
	{
	submenu=[this_node getSubmenu:x];
	if ([submenu isLeafNode])
	    //  submenu object has no submenus
	    {
	    //xmenu=[[this_menu addItem: [submenu getName] action:[submenu getMessage] keyEquivalent:      0] setTarget:      [submenu getReceiver]];
	
            [ [this_menu addItemWithTitle:[submenu getNameAsString] action:[submenu getMessage] keyEquivalent:@""] setTarget:[submenu getReceiver]];

	    }
	else
	    {
	    //tempmenu=[[NSMenu allocFromZone:[NSMenu menuZone]] initWithTitle: [submenu getName]];
            tempmenu=[[NSMenu alloc] initWithTitle: [submenu getNameAsString]];
            [this_menu setSubmenu: tempmenu forItem: [this_menu addItemWithTitle: [submenu getNameAsString] action: @selector(_junkSelector) keyEquivalent: @""]];
	    
	    [self generateMenu: submenu : tempmenu];
	    }
	}
    return self;
    }




/**** loadHelp::
  Loads the help text for a given module.  Called from a menu option.
*/

- loadHelp:sender
    {
    int selectedRow;
    selectedRow = [ [sender menu] indexOfItemWithTitle:[sender title]];

    [moduleHelpView readRTFDFromFile: [helpfiles objectAtIndex:selectedRow]];
    [moduleHelpWindow setTitle:[helpnames objectAtIndex:selectedRow]];
    [moduleHelpWindow makeKeyAndOrderFront:self];
    return self;
    }


/**** GenerateHelpMenu:::
  Adds a module's help menu item into the module help meu.  Also loads the filename
  information into the ModuleController's table so it can load the help information
  when the user chooses this menu item.
*/

- generateHelpMenu:(NSString*)helpResourcePath:(NSString*)moduleName:this_menu
    {
    numhelp++;

    [helpfiles addObject: helpResourcePath];
    [helpnames addObject: moduleName];
    
    [[this_menu addItemWithTitle: moduleName action: @selector(loadHelp:) keyEquivalent: @""] setTarget:self];
    return self;
    }


/**** TurnOffMenu:
  Turns off the module menu.  A legacy method, I believe.
*/

- turnOffMenu:sender
    {
    [adjustButton setEnabled:NO];
    return self;
    }

/**** TurnOnMenu:
  Turns on the module menu.  A legacy method, I believe.
*/

- turnOnMenu:sender
    {
    [adjustButton setEnabled:YES];
    return self;
    }


// Protocol Methods


/*** Protocol Methods
  For information on protocol methods, see the ModuleProtocol.rtf file.
  They're pretty straightforward.
*/




- (BOOL) runCompactPanel
    {
    int answer=
	NSRunAlertPanel(@"Large Operation",@"This operation may take a long time to perform on this sound, and cannot be stopped.",@"Go Ahead",@"Cancel",nil);
    if (answer==NSAlertDefaultReturn) return YES;
    return NO;
    }

- (BOOL) runLongTimePanel
    {
    return [self runCompactPanel];
    }

- run16BitOnlyPanel
    {
    NSRunAlertPanel(@"16-Bit Sound",@"This operation requires 16-bit linear formatted sound.",@"Oh",nil,nil);
    return self;
    }

- runNoSoundPanel
    {
    NSRunAlertPanel(@"No Sound",@"There is no selected sound on which to perform this operation",@"Oh",nil,nil);
    return self;
    }

- currentSound
    {
    return [fileController currentSound:self];
    }

- currentSoundView
    {
    return [fileController currentSoundView:self];
    }

- currentWindow
    {
    return [fileController currentWindow:self];
    }

- currentScrollView
    {
    if ([fileController currentWindow:self]==nil)
	{return nil;}
    else
	{return [[fileController currentWindow:self] contentView];}
    }

- currentPlayingSound
    {
    if ([self isPlaying])
	{
	return [soundManager soundPlayingOrRecording];
	}
    return nil;
    }

- currentPlayingSoundView
    {
    if ([self isPlaying])
	{
	return [fileController soundViewForSound:
		[soundManager soundPlayingOrRecording]];
	}
    return nil;
    }

- currentPlayingWindow
    {
    if ([self isPlaying])
	{
	return [[fileController soundViewForSound:
		 [soundManager soundPlayingOrRecording]] window];
	}
    return nil;
    }

- brandNewSound: thisSound
    {
    [fileController newRecordedSound: thisSound];
    return self;
    }


- newSound: thisSound for: thisSoundView
    {
    [fileController newSound: thisSound for: thisSoundView:self];
    return self;
    }

- soundChanged
    {
    id currentSound=[fileController currentSound:self];
    if (currentSound!=nil) 
	{
	[fileController soundChanged:currentSound];
	[zoomController findSelection:self];
	}
    return self;
    }

- soundTouched
    {
    /* obselete method.  Now it just calls soundChanged */
    return [self soundChanged];
    }

- selectionChanged
    {
    id currentSound=[fileController currentSound:self];
    if (currentSound!=nil) 
	{
	[selectionManager update:self];
	[zoomController findSelection:self];
	}
    return self;
    }

- fragmentationChanged
    {
    id currentSound=[fileController currentSound:self];
    if (currentSound!=nil) [infoManager changeInfo:currentSound];
    return self;
    }

- infoChanged
    {
    return [self soundChanged];
    }

- zoomChanged
    {
    id currentSound=[fileController currentSound:self];
    if (currentSound!=nil) 
	{
	[zoomController zoomChanged:self];
	[zoomController findSelection:self];
	}
    return self;
    }

- stop
    {
    [soundManager stop:self];
    return self;
    }

- (BOOL) isPlaying
    {
    return [soundManager isPlaying];
    }

- (BOOL) isRecording
    {
    return [soundManager isRecording];
    }

- moduleWindowDidBecomeMain
    {
    [fileController moduleWindowDidBecomeMain];
    return self;
    }

- soundDidRecord
    {
    [modules makeObjectsPerformSelector:@selector(didRecord)];
    return self;
    }

- soundDidPlay
    {
    [modules makeObjectsPerformSelector:@selector(didPlay)];
    return self;
    }

- soundNowPlaying
    {
    [modules makeObjectsPerformSelector:@selector(nowPlaying)];
    return self;
    }

- soundNowRecording
    {
    [modules makeObjectsPerformSelector:@selector(nowRecording)];
    return self;
    }

- update
    {
    [modules makeObjectsPerformSelector:@selector(soundDidChange)];
    return self;
    }

#ifdef PASTE_BUG
- (BOOL) stillExists
    {
    return [fileController stillExists:(void*)[[NSPasteboard generalPasteboard] owner]];
    }

- (BOOL) isOwner:this_sound_or_soundview
    {
    void* k=(void*)[[NSPasteboard generalPasteboard] owner];
    if ([this_sound_or_soundview isKindOf:[SoundView class]])
	{
	if (k==nil) return NO;
	return (k==this_sound_or_soundview||
		k==[this_sound_or_soundview sound]||
		k==[this_sound_or_soundview soundBeingProcessed]);
	}
    else {if (k==nil) return NO; return (k==this_sound_or_soundview);}
    }

- invalidatePasteboard
    {
    return [fileController invalidatePasteboard];
    }
#else

- (BOOL) stillExists { return YES; }
- (BOOL) isOwner:this_sound_or_soundview { return YES; }
- invalidatePasteboard { return self; }
#endif



- (void)newWindow:(NSWindow**) theWindowPointer:(NSScrollView**) theScrollViewPointer:(SoundView**)theSoundViewPointer
// creates and returns a new window, scrollview, and sound view without adding them to
// the Sound Table.
	{
	[fileController newWindow:theWindowPointer:
		theScrollViewPointer:theSoundViewPointer];
	[*theSoundViewPointer setDelegate:nil];
	[*theWindowPointer setDelegate:nil];
	}





@end
