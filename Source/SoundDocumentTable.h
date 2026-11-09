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



/*
 SoundDocumentTable (and SoundDocument)

 The SoundDocumentTable code is used by the FileController to manage SoundDocument
 storage objects.  It's basically an n-ary association lookup table.  Each
 SoundDocument has an associated sound, sound view, window, etc.
 */

#import <SndKit/SndKit.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "ResoundMiscSoundView.h"


/* SoundDocument
 
   A SoundDocument represents all the elements necessary to display a given sound
   in a given window.  A SoundDocument contains the following items:

   - a Sound object
   - the ResoundMiscSoundView the sound is being displayed in
   - the NSWindow the soundview is located in
   - an "untitledValue".  This is an integer.  If the integer is equal to
     SOUNDDOCUMENT_TITLED, then the document is representing a specific .snd
     file.  Otherwise, the document is considered "untitled" (even if it was
     loaded from a foreign sound file) and will receive a window title of
     UNTITLEDx, where x is the untitledValue.  If x is 0, it's just set to
     UNTITLED.  You shouldn't really set untitledValues in general.
   - a filename (an NSString).  Filenames are either:
      - proper NSString-style path names, if the SoundDocument is representing
        a specific .snd file.  In this case, the value of what's actually in
        the filename is important for saving the file.
      - possibly a path name, if the SoundDocument represents something that
        was read from a foreign sound file (.aiff, .au, .wav, .~snd, etc.)
        In this case, a path name is *convenient* for displaying in the title
        bar of the window but otherwise has no significance; you can set it
        to "Hello, Mom!" for all I care.
      - an empty string if the SoundDocument was created fresh.  In this case,
        the contents of the file are again insignificant except for displaying
        in the title bar.
   - a "soundChanged" boolean.  This indicates whether or not the window has
     edited data and needs to be saved out (YES).

A quick note on the "title" method.  This method returns an appropriate title
for the window.  But OPENSTEP tends to like to format its own window titles if
they're representing files.  So instead you should do something like this

- setTitleOfWindow:(NSWindow*)win fromDocument:(SoundDocument*)doc
  {
  if ([doc untitledValue]==SOUNDDOCUMENT_TITLED)
      [win setTitleWithRepresentedFilename:[doc filename]];
  else [win setTitle:[doc title]];
  }

By the way, you can apparently change the title of the window with setTitle,
and it'll keep its little title-bar icon thing if you've previously called
setTitleWithRepresentedFilename.  Useful!

*/


#define SOUNDDOCUMENT_TITLED -1 /* untitledValue when sound is in fact titled */




@interface SoundDocument:NSObject
{
    Snd* sound;
    ResoundMiscSoundView* soundView;
    NSWindow* window;
    BOOL soundChanged;
    NSString* filename;
    int untitledValue;
}
- initWithSound:(Snd*)s soundView:(ResoundMiscSoundView*)sv window:(NSWindow*)w filename:(NSString*)f untitledValue:(int)uv;
- (void) dealloc;
- (Snd*) sound;
- (ResoundMiscSoundView*) soundView;
- (NSWindow*) window;
- (BOOL) soundChanged;
- (NSString*) filename;
- (void) setSound:(Snd*)this;
- (void) setSoundView:(ResoundMiscSoundView*)this;
- (void) setWindow:(NSWindow*)this;
- (void) setSoundChanged:(BOOL)this;
- (void) setFilename:(NSString*)this;  /* except untitled docs, even if
	they have a so-called "filename" (their previous name) */
- (int) untitledValue;  /* if -1, then document is titled */
- (void) setUntitledValue:(int)this;
- (BOOL) contains:(NSObject*)this;
- (NSString*) title;   /* acceptable title for an untitled document;
                          see note above about setting window titles. */
- (NSString*) simpleTitle;   /* acceptable short title for displaying in a dialog box */
- (void) documentWasSaved:(NSString*)_filename;  /* sets the document to titled and unedited */

@end




@interface SoundDocumentTable:NSObject
{
    NSMutableArray* soundDocuments;
    int nextUntitledValue;
}

- init;
- (void) dealloc;
- (SoundDocument*) newDocument:(Snd*)thisSound:(ResoundMiscSoundView*)thisSoundView:(NSWindow*)thisWindow:(NSString*)thisFilename:(BOOL)isUntitled;
- (void) remove:(SoundDocument*) document;
- (NSEnumerator*) objectEnumerator;

    /* Finding an item */
- (SoundDocument*) find:object;
- (SoundDocument*) findFilename:(NSString*)filename;
- (SoundDocument*) findMainWindow;

/* Convenience Queries */
- (BOOL) changedSoundExists;
- (BOOL) empty;

@end