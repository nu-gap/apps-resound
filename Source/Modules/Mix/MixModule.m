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

	#import "MixModule.h"
	#import <SndKit/SndKit.h>
	#import <AppKit/AppKit.h>

@interface SndView(Mix)
- mix:(id)moduleController;
@end



	@implementation MixModule

	-init
		{
		id returnVal=[super init];
		
		ModuleMenuNode* mixNode=[[ModuleMenuNode alloc] initLeafNode:
			@"Mix In":self:@selector(mix:)];
		
		[rootModuleMenuNode addSubmenu: mixNode];
		
		return returnVal;
		}
		
	- mix:sender
		{
                NSMutableArray* array=[NSMutableArray arrayWithCapacity:1];
		SndView* cview=[moduleController currentSoundView];
#ifdef PASTE_BUG
                id pb=[NSPasteboard generalPasteboard];
#endif

                /* First, determine if we can mix or not */
                [array addObject:SndPasteboardType];

#ifdef PASTE_BUG
                if (![[pb availableTypeFromArray:array] isEqualToString:SndPasteboardType])
			{
			return nil;
			}
		else if (![moduleController stillExists])
			{
			[moduleController invalidatePasteboard];
	
			/* Now, don't paste */
			return nil;
			}
#endif	
		// we can paste!	

		[cview mix:moduleController];
		[moduleController soundChanged];
		return self;
		}	

	@end


@implementation SndView(Mix)


- mix:(id)moduleController
	{
	unsigned int size, selection;
	int x;
	Snd* s;
	unsigned char* data1;
	unsigned char* data2;
	int ch;
	int num_bytes=1;

	id tmpsoundview;
	id tmpscrollview;
	NSWindow* tmpwindow;
	/* 1998 also declared an NSRect tmprect here, for the
	   commented-out window-creation block below; with that block
	   commented out the variable is unused, so the declaration is
	   gone (it would trip -Wall -Wunused-variable). */
	
        /* Compact the sound--ouch! */

        if ([[self sound] needsCompacting]) [[self sound] compactSamples];
        



	/* First, we need a sound from the pasteboard.  Rhapsody has made
	   this difficult because initFromPasteboard doesn't work any more!
	   And if we use SoundView, we get bitten by the cursor bug.
           So we have no choice but to use ResoundMiscSoundView, which is
	   against the rules. :-(  So I've included ResoundMiscSoundView
	   and MiscSoundView here.  There's probably got to be a better way
	   to do this (maybe a ModuleProtocol option that returns a fresh
	   one for ya). */
        s=[[[Snd alloc] init] autorelease];
/*	tmprect.size.width=10; tmprect.size.height=10;
	tmprect.origin.x=0; tmprect.origin.y=0; // make something up
	tmpwindow=[[[NSWindow alloc] initWithContentRect:tmprect
		styleMask:0 backing:NSBackingStoreBuffered defer:NO] autorelease];
        tmpscrollview=[[[NSScrollView alloc] initWithFrame:tmprect] autorelease];
	tmpsoundview=[[[ResoundMiscSoundView alloc] initWithFrame:tmprect] autorelease];

        [tmpsoundview setIgnoreShowAndHideCursor:YES];
        [tmpwindow setContentView:tmpscrollview];
        [tmpscrollview setDocumentView:tmpsoundview];
        [tmpsoundview setIgnoreShowAndHideCursor:NO];*/
        [moduleController newWindow:&tmpwindow:&tmpscrollview:&tmpsoundview];

        [(SndView*)tmpsoundview setSound:s];	// TypeCast for OS X server
        [tmpsoundview readSelectionFromPasteboard: [NSPasteboard generalPasteboard]];

	[s 	convertToSampleFormat:[[self sound] dataFormat] 
		samplingRate:[[self sound] samplingRate]
		channelCount:[[self sound] channelCount]];
	
	/* SndKit buffer-list artifact (not in the 1998 SoundKit): a
	   fresh [[Snd alloc] init] carries one zero-frame buffer, and
	   the readSelectionFromPasteboard: above inserts the pasted
	   samples into that buffer rather than replacing the sound,
	   leaving a two-buffer sound whose first buffer is empty;
	   -[Snd bytes] reads buffer 0, so the DSP below would
	   dereference NULL.  The 1998 code never needed this; see
	   docs/UPSTREAM_PATCHES.md, the MusicKit-0006 verification
	   note, for the artifact itself (left unpatched in SndKit). */
	if ([s needsCompacting]) [s compactSamples];
	
	/* determine size and selection */
	
	[self getSelection:&selection size:&size];
	if (size==0) size=[[self sound] lengthInSampleFrames]-selection;  // to end of sound
	if (size>[s lengthInSampleFrames]) size=[s lengthInSampleFrames];		// whittle to min sound
	if (size==0) return self;			// huh?  nothing to mix into
	/* 1998: if (selection<0||selection>=[[self sound] sampleCount]) return self;
	   -[SndView getSelection:] hands out unsigned ints (SndView.h), so
	   the selection<0 half is a dead comparison for an unsigned and
	   is kept only for the 1998 shape; -Wall does not flag it. */
	if (selection<0||selection>=[[self sound] lengthInSampleFrames]) return self; // huh?
	

	/* load the data */
	
	data1=(unsigned char*)[s bytes];
	data2=(unsigned char*)[[self sound] bytes];
	
	/* The 1998 code swapped both buffers to host order here (the
	   1998 SoundKit kept sample data big-endian) and back at the
	   end, fetching ch/sa/df from each sound around its own swap.
	   SndKit keeps sample data in host byte order, so both swaps
	   are gone (the Zero port made the same change); after the
	   conversion above the two sounds share the document's channel
	   count, so a single fetch feeds num_bytes. */
	ch=[[self sound] channelCount];
	
	num_bytes=ch;  // channels makes all the difference!
	
	// The document's data format selects the DSP below.  If it is
	// SND_FORMAT_MULAW_8, the linear values are mixed and re-encoded
	// (1998's SNDMulaw/SNDiMulaw pair is SndKit's
	// SndLinearToMuLaw/SndMuLawToLinear, plus SndKit's LINCLIP - the
	// 1998 SNDMulaw clipped inside).  If it's something weird, we
	// have to refuse mixing.
	

	switch([[self sound] dataFormat])
		{
		case SND_FORMAT_MULAW_8: 
			{
			char* d1=(char*)data1;
			char* d2=(char*)data2;
			int lin;
			for (x=selection*num_bytes;
				 x<selection*num_bytes+size*num_bytes;
				 x++)
				{
				/* 1998: d2[x]=SNDMulaw(SNDiMulaw(d2[x])+
				   SNDiMulaw(d1[x-selection*num_bytes]));
				   The 1998 SNDMulaw took the int sum and clipped
				   inside; SndKit's SndLinearToMuLaw takes a short,
				   so the port clips with SndKit's own LINCLIP
				   (MINLIN/MAXLIN from SndMuLaw.h) first. */
				lin=SndMuLawToLinear((unsigned char)d2[x])+
					SndMuLawToLinear((unsigned char)d1[x-selection*num_bytes]);
				LINCLIP(lin);
				d2[x]=SndLinearToMuLaw((short)lin);
				}
			} break;
		case SND_FORMAT_LINEAR_8:
			{
			char* d1=(char*)data1;
			char* d2=(char*)data2;
			for (x=selection*num_bytes;
				 x<selection*num_bytes+size*num_bytes;
				 x++)
				d2[x]+=d1[x-selection*num_bytes];
			} break;
		case SND_FORMAT_LINEAR_16:
			{
			signed short* d1=(signed short*)data1;
			signed short* d2=(signed short*)data2;
			for (x=selection*num_bytes;
				 x<selection*num_bytes+size*num_bytes;
				 x++)
				d2[x]+=d1[x-selection*num_bytes];
			} break;
		case SND_FORMAT_FLOAT:
			{
			float* d1=(float*)data1;
			float* d2=(float*)data2;
			for (x=selection*num_bytes;
				 x<selection*num_bytes+size*num_bytes;
				 x++)
				d2[x]+=d1[x-selection*num_bytes];
			} break;
		case SND_FORMAT_DOUBLE:
			{
			double* d1=(double*)data1;
			double* d2=(double*)data2;
			for (x=selection*num_bytes;
				 x<selection*num_bytes+size*num_bytes;
				 x++)
				d2[x]+=d1[x-selection*num_bytes];
			} break;
		default: 	
			NSRunAlertPanel(@"Mix",
				@"Can't mix this format.",@"Oops",nil,nil);
 			break;
		}

	/* (The 1998 code swapped both buffers back to big-endian
	   storage here; SndKit keeps host order, so the pair is gone -
	   see above.) */

	return self;
	}


@end
