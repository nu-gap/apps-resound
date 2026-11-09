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

#import "SoundDocumentTable.h"


@interface NSWindow(RetainRelease)
- retain;
- (oneway void) release;
@end

@implementation NSWindow(RetainRelease)
- retain { return [super retain]; }
- (oneway void) release { [super release]; }
@end


@implementation SoundDocument

- initWithSound:(Snd*)s soundView:(ResoundMiscSoundView*)sv window:(NSWindow*)w filename:(NSString*)f untitledValue:(int)uv;
{ sound=[s retain]; soundView=[sv retain]; window=[w retain]; filename=[f retain]; untitledValue=uv; soundChanged=
	(untitledValue==SOUNDDOCUMENT_TITLED ? NO : YES);
return [super init];
}
- (Snd*) sound { return sound; }
- (ResoundMiscSoundView*) soundView { return soundView; }
- (NSWindow*) window { return window; }
- (BOOL) soundChanged { return soundChanged; }
- (NSString*) filename { return filename; }
- (int) untitledValue {return untitledValue; }
- (void) setSound:(Snd*)this 
	{ if (sound!=nil) [sound release]; sound = [this retain]; }
- (void) setSoundView:(ResoundMiscSoundView*)this 
	{ if (soundView!=nil) [soundView release]; soundView = [this retain]; }
- (void) setWindow:(NSWindow*)this 
	{ if (window!=nil) [window release]; window = [this retain]; }
- (void) setSoundChanged:(BOOL)this { soundChanged = this; }
- (void) setFilename:(NSString*)this 
	{ if (filename!=nil) [filename release]; filename = [this retain]; }
- (void) setUntitledValue:(int)this {  untitledValue=this; }
- (BOOL) contains:(NSObject*)this
    {
    return( (NSObject*)sound == this ||
            (NSObject*)soundView == this ||
            (NSObject*)window == this ||
            (NSObject*)filename == this);
    }

- (NSString*) title
{
  if (untitledValue==SOUNDDOCUMENT_TITLED)
      return filename;
  else if (untitledValue==0)
	{
      if (filename==nil||[filename isEqualToString:@""]) return @"UNTITLED";
      else return [NSString stringWithFormat:@"UNTITLED (%@)",
          filename];
      }
  else
      {
      if (filename==nil||[filename isEqualToString:@""])
          return [NSString stringWithFormat:@"UNTITLED%d",untitledValue];
      else return [NSString stringWithFormat:@"UNTITLED%d (%@)",
		untitledValue,filename];
      }
}

- (NSString*) simpleTitle
{
    if (untitledValue==SOUNDDOCUMENT_TITLED) return [filename lastPathComponent];
    else if (untitledValue==0) return @"UNTITLED";
    else return [NSString stringWithFormat:@"UNTITLED%d",untitledValue];
}

- (void) dealloc
    {
// why are these autorelease and not release?  Well, a document
// is usually deallocated when the user clicks on the close button
// of a window; when this happens, the system sends the FileController
// a windowShouldClose: call, which the FileController uses to determin
// if the window should really close, if we should save first, etc.  During
// that time, if we REALLY should eliminate the window, the appropriate
// sound document is deallocated.  BUT...the application's not closed the
// window yet!  It will with a close message immediately after windowShouldClose
// finishes (which is right after we finish deallocing).  So we autorelease,
// which gives the system time to close the window, and then the event loop
// can release the window for us.  Got it?

    if (sound) [sound autorelease];
    if (soundView) [soundView autorelease];  // this should be before window
    if (window) [window autorelease];
    if (filename) [filename autorelease];
    [super dealloc];
    }


- (void) documentWasSaved:(NSString*)_filename
{
    [self setFilename:_filename];
    [self setSoundChanged:NO];
    [self setUntitledValue:SOUNDDOCUMENT_TITLED];
}

@end




@implementation SoundDocumentTable


- init
    {
    id returnval=[super init];
    soundDocuments = [[NSMutableArray alloc] initWithCapacity:256];
    nextUntitledValue=SOUNDDOCUMENT_TITLED;  /* the beginning */
    return returnval;
    }

- (void) dealloc
{
    [soundDocuments removeAllObjects];
    [soundDocuments release];
    [super dealloc];
}

- (int) size
{
    return [soundDocuments count];
}

- (SoundDocument*) newDocument:(Snd*)thisSound:(ResoundMiscSoundView*)thisSoundView:(NSWindow*)thisWindow:(NSString*)thisFilename:(BOOL)isUntitled
{
    SoundDocument* sd=[[[SoundDocument alloc] initWithSound:thisSound 
	soundView:thisSoundView 
	window:thisWindow 
	filename:thisFilename untitledValue:(isUntitled ? ++nextUntitledValue : -1)]
		autorelease];
    [soundDocuments addObject:sd];
    return sd;
}


- (void) remove:(SoundDocument*) this
{
    [soundDocuments removeObject:this];
}


/* Enumeration */
- (NSEnumerator*) objectEnumerator
{
    return [soundDocuments objectEnumerator];
}

    /* Finding an item */
- (SoundDocument*) find:object
{
    NSEnumerator *enumerator = [soundDocuments objectEnumerator];
    SoundDocument* anObject;
    while((anObject = (SoundDocument*)([enumerator nextObject]))!=nil)
            {
        if ([anObject contains:object]) return anObject;
            }
    return nil;
}

- (SoundDocument*) findFilename:(NSString*)filename
{
    NSEnumerator *enumerator = [soundDocuments objectEnumerator];
    SoundDocument* anObject;
    while((anObject = (SoundDocument*)([enumerator nextObject]))!=nil)
            {
        NSString* fn=[anObject filename];
        if (fn!=nil)
            if ([fn compare:filename]==NSOrderedSame && 
		[anObject untitledValue]==SOUNDDOCUMENT_TITLED) return anObject;
            }
    return nil;
}

- (SoundDocument*) findMainWindow
{
    return [self find:[NSApp mainWindow]];
}

- (BOOL) changedSoundExists
{
    NSEnumerator *enumerator = [soundDocuments objectEnumerator];
    SoundDocument* anObject;
    while((anObject = (SoundDocument*)([enumerator nextObject]))!=nil)
            {
        if ([anObject soundChanged]) return YES;
            }
    return NO;
}

- (BOOL) empty
{
    return ([soundDocuments count]==0);
}

@end
