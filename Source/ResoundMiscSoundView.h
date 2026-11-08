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


#import "MiscSoundView.h"

#define UPDATESOUNDVIEW_XAXIS_DISPLAY_FORMAT_TICKS	1		/* obselete */
#define UPDATESOUNDVIEW_XAXIS_DISPLAY_FORMAT_GRID	0		/* obselete */
#define MAXIMUM_BYTES_FOR_SILENT_PASTE                  (1024 * 1024)   /* 1 meg */

#ifdef PASTE_BUG
@interface NSPasteboard(ChangeOwn)
- (void*) owner;
- changeOwner:(void*) new_owner;
@end
#endif

@interface ResoundMiscSoundView:MiscSoundView
    {
    id selectionInspector;
    id cursor;
    BOOL continuousUpdate;
    BOOL continuousZoom;
    NSString* info_string;
    BOOL ignoreShowAndHideCursor;
    BOOL dataOnPasteboard;
    int sizeOfDataOnPasteboard;
    int pasteboardCount;
    }

- (void) setIgnoreShowAndHideCursor:(BOOL) this;
#ifdef PASTE_BUG
- (void) paste:sender;    // only pastes if owner exists
- (void) cut:sender;	   // invalidates pasteboard if necessary
- (void) copy:sender;	   // invalidates pasteboard if necessary
#else
// new Paste bug fixes
- (void) cut:sender;
- (void) copy:sender;
#endif
- setCursor:this_cursor;
- resetCursorRects;
- (BOOL) continuousZoom;
- updateStuff;
- (void)drawRect:(NSRect)rects;
- setContinuousUpdate:(BOOL) this_update;
- setContinuousZoom:(BOOL) this_zoom;
- initWithFrame:(NSRect) frameRect;
- setSelectionManager: aSelectionManager;
- update:
(BOOL) display_the_x_axis:
(BOOL) display_the_y_axis:
(BOOL) display_the_labels:
(BOOL) display_the_zero_line:
(int) this_x_display_format:
(int) this_major_tick_spacing:
(float) this_minor_tick_spacing:
(int) this_minor_tick_spacing_format:
(int) this_y_display_format:
(BOOL) do_scroll_to_reflect_playing;
- setScrollValue:(double)this_value;
- (double) scrollValue;							// a private method
- (void) dealloc;
- (BOOL)sampleIsVisible:(int)sample;
- loadInfo:(Snd*)s;
- (NSString*)info;
- setInfo:(NSString*)this;
- (void)checkForCurrentDataOnPasteboard;
- (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type;
- (void)pasteboardChangedOwner:(NSPasteboard *)sender;

@end
