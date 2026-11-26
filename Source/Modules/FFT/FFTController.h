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
#import <SndKit/SndKit.h>
#import "DiscreteGraphView.h"


@interface FFTController:NSObject
{
	id	freqview;
	id	phasview;
	id  minimumdbfield;
	int islinear;
	id  decibelButton;
	float* f1;
	float* f2;
	float* p1;
	int n;
}

- drawFFT:(Snd*) this_sound:(SndView*)
			this_soundview: (int)start_sample:(int)number_samples;
- setDelegates:x:y;
- init;
- toggleLinearAndDecibel:sender;
- redrawGraphs:sender;

@end