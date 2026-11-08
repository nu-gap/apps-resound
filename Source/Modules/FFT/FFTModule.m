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
#import "FFTModule.h"
#import "ResoundNibs.h"
#import "FFTController.h"
#import <AppKit/AppKit.h>
#import <SoundKit/SoundKit.h>
#include <stdio.h>

@implementation FFTModule

-	init
	{
	id returnVal=[super init];

	ModuleMenuNode* fftnode=[[ModuleMenuNode alloc] initLeafNode:
		@"FFT...":self:@selector(showFFTPanel:)];
	[rootModuleMenuNode addSubmenu:fftnode];
	nib_loaded=NO;
	return returnVal;
	}
	
- showFFTPanel:sender
	{
	if (!nib_loaded)
		{
		[ResoundNibs loadNibNamed: @"FFT" owner:self];
		nib_loaded=YES;
		}
	[fftController setDelegates:x:y];
	[fftPanel makeKeyAndOrderFront:self];
	return self;
	}
	
- doFFT:sender
	{
	id sv=[moduleController currentSoundView];
	int fs, sc;
	[sv getSelection: &fs size: &sc];
	[fftController drawFFT:[moduleController currentSound]:sv:fs:sc];
	return self;
	}

@end