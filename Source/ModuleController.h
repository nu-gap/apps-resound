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



#import <Foundation/Foundation.h>
#import "ModuleProtocol.h"

@interface ModuleController:NSObject <ModuleProtocol>
    {
    id fileController;
    id infoManager;
    id soundManager;
    id zoomController;
    id selectionManager;
    id compactPanel;
    id adjustButton;
    id loadPanel;
    id fileName;
    id pathName;
    NSMutableArray* modules;
    NSMutableArray* helpnames;
    NSMutableArray* helpfiles;
    int numhelp;
    
    id moduleHelpView;
    id moduleHelpWindow;
    
    BOOL goAhead;		     //  The Compact Panel has been okayed.
    
    int loaded;
    int windowsLoaded;
    }


/*---------Private methods. On pain of death, do not call these methods-they are internal---------*/

- init;
- (void) dealloc;
- loadModules;
- (void) loadAModule: (NSString *)file;
- generateHelpMenu:(NSString*) helpResourcePath:(NSString*)moduleName:this_menu;
- generateMenu:this_node:this_menu;		// do not call this.  Used by LoadModules
- turnOffMenu:sender;
- turnOnMenu:sender;
- update;
- soundDidRecord;
- soundDidPlay;
- soundNowPlaying;
- soundNowRecording;






/*---------------------METHODS PROPERLY CALLABLE BY MODULES----------------------*/

// See ModuleProtocol.h for comments on these methods.

- (BOOL) runCompactPanel;
- (BOOL) runLongTimePanel;
- run16BitOnlyPanel;
- runNoSoundPanel;

- currentSound;
- currentSoundView;
- currentWindow;
- currentPlayingSound;
- currentPlayingSoundView;
- currentPlayingWindow;	

- brandNewSound: thisSound;
- newSound: thisSound for: thisSoundView;

- soundChanged;
- soundTouched;
- selectionChanged;
- infoChanged;
- zoomChanged;

- stop;	
- (BOOL) isPlaying;
- (BOOL) isRecording;

- moduleWindowDidBecomeMain;


/* Pasteboard bug fixes -- no longer applicable to Rhapsody */
- (BOOL) stillExists;
- (BOOL) isOwner:this_sound_or_soundview;
- invalidatePasteboard;



@end
