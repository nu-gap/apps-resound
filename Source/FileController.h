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

#import <Foundation/Foundation.h>
#import <AppKit/NSWindow.h>
#include <sys/param.h>		// MAXPATHLEN
#import "SoundDocumentTable.h"

/*
  The Sound (ResoundSound) file-I/O category that used to be
  declared here moved to Source/Sound-ResoundSound.h with the SndKit
  migration (see docs/RESOUND_SNDKIT_PLAN.md, Phase 1).
*/




@interface FileController:NSObject
   {
   SoundDocumentTable*  soundTable;
   id  editController;
   id  moduleController;
   id  soundManager;
   id  preferencesManager;
   id  consoleManager;
   id  selectionInspector;
   id  inspectorManager;
   
   /* Menu items that can be turned on and off... */
   id  saveButton;
   id  saveAsButton;
   id  saveAllButton;
   id  closeButton;
   id  revertButton;

   id mainMenu;

   NSWindow* currentWindow;   // the current sound window

   id soundViewCursor;   
   int shouldCloseWindow;
   
   id junkField;				// used to cut null data to invalidate
                                                // soundviews' cut data
   int ignorethis;				// ignore windowWillClose messages
   
   NSString* defaultPath;
   int currentUntitledValue;    // for UNTITLED 1, UNTITLED 2, etc.
   }

- init;

- newRecordedSound: ThisSound;					
- newSoundFromPasteBoard:sender;
- newSoundFromMicrophone:sender;	//  same as pressing record on Console
- open:sender;				// 	opens sounds. Similar to New.

- close:sender;
- quit:sender;
- saveAll:sender;
- save:sender;
- saveAs:sender;

- revert:sender;



- print:sender;
- doPageLayout:sender;

- soundChanged:ThisSound;			// sets sound edited flags in
//	sound table, and sets the window
//	close box to a broken X.

// 	The following are very useful.
//	They return ids to the current
//	window, sound, or soundview.


- currentWindow:sender;				/*returns NULL if no Current*/
- currentSound:sender;				// ditto
- currentSoundView:sender;			// ditto

- soundViewForSound:sound;			// Convenience function for Console


- newSound: thisSound for: thisSoundView: sender;
	// used ONLY by the ModuleController
                                // to replace a current soundview's sound.
- update;

- setPlaying:(NSWindow*) win:(BOOL) to_this;

#ifdef PASTE_BUG
- (BOOL) stillExists:(void*) pointer;
- invalidatePasteboard;
#endif

 /* FUNCTION TO CONNECT MODULES DYNAMICALLY LOADED */

 - getModuleController;

 @end

