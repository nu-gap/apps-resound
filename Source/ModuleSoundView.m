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

  ModuleSoundView.[h|m]
  Sean Luke
  
  ModuleSoundView is a category defining methods that module makers have
  available to them when manipulating sound views.  The only one of note is
  convertToSampleFormat;samplingRate:channelCount, which preserves selection.  
  
  ****************************************************************************/


#import "ModuleSound.h"

@implementation SndView(ModuleSoundView)


/**** convertToSampleFormat:samplingRate:channelCount
  Converts to a given format, sampling rate, and channel count, but attempts
  to preserve the selection.  Without this method, making a conversion results
  in incorrect selections.  A most useful method.
  */


- (int)	convertToSampleFormat:(int)newFormat
 samplingRate:(double)newRate
 channelCount:(int)newChannelCount
 
 /* we attempt to preserve the selection across new sampling rates */
    {
    double oldrate=[[self sound] samplingRate];
    int selection;
    int size;
    int error;
    
    [self getSelection:(unsigned int*)&selection size:(unsigned int*)&size];
    error=[[self sound] convertToSampleFormat:newFormat 
	 samplingRate:newRate channelCount:newChannelCount];
    
    if (oldrate==0) oldrate=newRate;		// just in case
    if (oldrate==0) return error;			// just in case
    selection*=newRate;
    selection/=oldrate;
    size*=newRate;
    size/=oldrate;
    [self setSelection:selection size:size];
    return error;
    }



/**** info
  Returns NULL.  Doesn't let the user have access to the Info String (okay, he
  really does, this is just a sanity-preservation formality).
  */

- (NSString*)info
    {
    return NULL;
    }


/**** setInfo
  Doesn't do anything.  Doesn't let the user have access to the Info String (okay, he
  really does, this is just a sanity-preservation formality).
  */

- setInfo:(NSString*)this
    {
    return self;
    }

/**** setIgnoreShowAndHideCursor:
  The default for ordinary sound views doesn't do anything at all.  This is an abstract
  supermethod which ResoundMiscSoundViews respond to.
*/

- (void) setIgnoreShowAndHideCursor:(BOOL)this
   {
   }

/**** checkForCurrentDataOnPasteboard
     The default for ordinary sound views doesn't do anything at all.  This is an abstract
     supermethod which ResoundMiscSoundViews respond to.
   */

- (void)checkForCurrentDataOnPasteboard
	{
}
@end
