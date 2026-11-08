/*

 MiscSoundView
 Version 2.0.2
 Copyright (c) 1995 by Sean Luke
 Copyright (c) 1998 by Jerome Genest, Frederic Bourget from Daffy Software.
 Donated to the MiscKit

 Permission to use, copy, modify, and distribute this material
 for any purpose and without fee, under the restrictions as noted
 in the MiscKit copyright notice, is hereby granted, provided that
 the MiscKit copyright notice and this permission notice
 appear in all source copies, and that the authors names shall not
 be used in advertising or publicity pertaining to this
 material without the specific, prior written permission
 of the author.  SEAN O. LUKE AMD JEROME GENEST  MAKE NO REPRESENTATIONS 
 ABOUT THE ACCURACY OR SUITABILITY OF THIS MATERIAL FOR ANY PURPOSE.
 IT IS PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.

*/
  
// Known Bugs:

//	1)  Play Mark doesn't disappear unless you tell it to.
//	2)	Rulers don't appear until explicitly told to.
//	3)	Ruler values slowly drift (rounding error) 
//	4) If the soundview bounds are set smaller than the scroll view (such as when changing the reduction factor)
//	   the disclosed region of the scroll view is not updated properly

#import "MiscSoundView.h"
#import "MiscSoundViewRuler.h"
#import <math.h>
#import <stdio.h>

// CONVENIENCE FUNCTIONS

double scroll_to_reduction (double scrollValue, double ratio)
	// scrollValue must be a number between 1 and 0
	// ratio is sample count / display units
	// returns -1 if error
	// this function considers roundoff to integers,
	// and a maximum value at integer point
	{
	if (scrollValue>1.0||scrollValue<0.0) 
		{
		printf ("scroll_to_reduction ERROR:  scrollValue is %f, ratio is%f\n", scrollValue, ratio);
		return -1.0;
		}
	return ceil(pow(ceil(ratio),scrollValue));
	}

	
double reduction_to_scroll (double reduction, double ratio)	
	// reduction must be a number above 1, preferably < ratio
	// ratio is sample count / display units
	// returns -1 if error
	// this function does not consider roundoff to integers...
	// but does consider a maximum value at integer point
	{
	if (reduction<1.0) 
		{
		printf ("reduction_to_scroll ERROR:  reduction is %f, ratio is %f\n", reduction, ratio);
		return -1.0;
		}
	return log(reduction)/log(ceil(ratio));
	}
	
	
// Rounds x to the nearest integer.

int MISCSOUNDVIEW_round(float x)
	{
	if (fabs(ceil(x)-x)<=0.5) return (int) ceil(x);
	return (int) floor(x);
	}
 

@implementation MiscSoundView

- (void) dealloc
	{
	if (rulerView!=nil) [rulerView release];
	[super dealloc];
}

// Private method that modify the bounds/frame rect...
// This is done to adjust the sndView to the presence / absence of the ruler

- _adjustBounds
{
	// This assumes that MiscSoundView is in a scrollView!
	// It also does _not_ draw the MiscSoundView...
	
	id scroll_view;
	NSSize ThisSize;
	
	if ((scroll_view=[self scrollView])==NULL) 
		{
		return NULL;		// not in scrollView!
		}
	
	ThisSize = [scroll_view contentSize];	
	[super setFrameSize:NSMakeSize([self bounds].size.width, ThisSize.height)];
		// the content size is adjusted when the ruler is shown / hidden !	
	return self;
}

- adjustBounds:sender
{	
	if ([self _adjustBounds]==NULL) 
		{return NULL;}
	[self display];
	return self;
}


- (void)setFrameSize:(NSSize)_newSize
	{
	[super setFrameSize:_newSize]; 
	[self _adjustBounds];
      	}


- initWithFrame:(NSRect)frameRect
{
	id returnval=[super initWithFrame:frameRect];
	display_x_axis_marks=NO;
	display_y_axis_grid=NO;
	display_zero_line=NO;
	display_labels=YES;
	y_display_format=MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_SIXTEEN;
	minor_tick_spacing=1000.0;
	minor_tick_spacing_format=MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES;
	major_tick_spacing=10;

	scroll_to_reflect_playing=NO;

        rulerView = [[MiscSoundViewRuler alloc] init];
	
	return returnval;
}

 
- (void)drawRect:(NSRect)rects
{


//-------------------------------------
//	Some DrawSelf Free-Form Poetry:
//
//	drawSelf is probably
//	the most evil monolithic Obj-C ever
//	created.  I can't bother
//	prettifying it, though I might
//	make it
//	barely understandable.
//-------------------------------------



	NSSize temp;
	float maxval,lastval;
	int a;
	int true_sample_count=[[self sound] lengthInSampleFrames];

        BOOL only_change_play_mark =  [rulerView onlyChangePlayMark];

	// Draw SoundView stuff
	if (!only_change_play_mark)
		{
		 [super drawRect:rects];
		}

	/*     
	 *
	 *
	 * Drawing the Y-Axis elements (Amplitude and Zero Line)...
	 *
	 *
	 *
	 */
	
	if (display_y_axis_grid&&!only_change_play_mark&&true_sample_count)
		{
		if (y_display_format==MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_DECIBEL)
			{
			maxval=SndConvertDecibelsToLinear(100.0);
			lastval=[self bounds].size.height/2;
			
			for (a=19;a>=10;a--)
				{
				temp.height=lastval-SndConvertDecibelsToLinear
					((float)a*5)/maxval*([self bounds].size.height/2);
				temp.width=0;
				temp = [self convertSize:temp toView:nil];
				if (temp.height>2.0)
					{
					PSsetlinewidth(0);
					PSsetgray(NSDarkGray);
					PSmoveto (rects.origin.x,SndConvertDecibelsToLinear
						((float)a*5)/maxval*([self bounds].size.height/2));
					PSrlineto(rects.size.width,0);
					PSsetlinewidth(0);
					PSmoveto (rects.origin.x,0-SndConvertDecibelsToLinear
						((float)a*5)/maxval*([self bounds].size.height/2));
					PSrlineto(rects.size.width,0);
					PSstroke();
					}
				lastval=SndConvertDecibelsToLinear
					((float)a*5)/maxval*([self bounds].size.height/2);
				}
			}
		else if (y_display_format==MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_SIXTEEN)
			{
			for (a=1;a<8;a++)
				{
				PSsetlinewidth(0);
				PSsetgray(NSDarkGray);
				PSmoveto (rects.origin.x,([self bounds].size.height/2)/8*a);
				PSrlineto(rects.size.width,0);
				PSsetlinewidth(0);
				PSmoveto (rects.origin.x,0-([self bounds].size.height/2)/8*a);
				PSrlineto(rects.size.width,0);
				PSstroke();	
				}		
			}
		else if (y_display_format==MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTY)
			{
			for (a=1;a<10;a++)
				{
				PSsetlinewidth(0);
				PSsetgray(NSDarkGray);
				PSmoveto (rects.origin.x,([self bounds].size.height/2)/10*a);
				PSrlineto(rects.size.width,0);
				PSsetlinewidth(0);
				PSmoveto (rects.origin.x,0-([self bounds].size.height/2)/10*a);
				PSrlineto(rects.size.width,0);
				PSstroke();	
				}		
			}
		else // y_display_format==MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTYFOUR
			{
			for (a=1;a<12;a++)
				{
				PSsetlinewidth(0);
				PSsetgray(NSDarkGray);
				PSmoveto (rects.origin.x,([self bounds].size.height/2)/12*a);
				PSrlineto(rects.size.width,0);
				PSsetlinewidth(0);
				PSmoveto (rects.origin.x,0-([self bounds].size.height/2)/12*a);
				PSrlineto(rects.size.width,0);
				PSstroke();	
				}		
			}
		}
	if (display_zero_line&&!only_change_play_mark&&true_sample_count)
		{
		PSsetlinewidth(0);
		PSsetgray(NSDarkGray);
		PSmoveto (rects.origin.x,0);
		PSrlineto(rects.size.width,0);
		PSstroke();
		}



	/*     
	 *
	 *
	 * Drawing the X-Axis elements (Ruler and Play-Mark)...
	 *
	 *
	 *
	 */
		
		
	if (display_x_axis_marks&&(minor_tick_spacing!=0.0)&&major_tick_spacing)				
	
		// display the axis
		
		{	
		// everything is now done in the ruler view !!	
		[rulerView display];
		}
}



- (void) getSelection:(int *)firstSample size:(int *)sampleCount
// a fixed version of getSelection which returns the proper selected area
// POSSIBLE BUG ALERT:  NeXT's stuff may depend on the broken getSelection!

{
	int samples=[[self sound] lengthInSampleFrames];
	// SndKit's getSelection: takes unsigned int* (1998 SoundView took
	// int*), so cast the 1998 int* parameters explicitly:
	[super getSelection:(unsigned int*)firstSample size:(unsigned int*)sampleCount];
	// Now we check and modify accordingly:
	if (*firstSample+*sampleCount>samples) *sampleCount=samples-*firstSample;
	//return self;
}



- (void) setSelection:(int)firstSample size:(int)sampleCount
// a fixed version of setSelection which sets the proper selected area
// POSSIBLE BUG ALERT:  NeXT's stuff may depend on the broken setSelection!

{
	int samples=[[self sound] lengthInSampleFrames];
	if (firstSample+sampleCount>=samples)
		// we make certain that the right amount is selected!
		// The 1998 soundView clamped a selection that extended beyond
		// the sound's end, and the code compensated by physically
		// widening the (stored) selectionRect by 10%.  SndKit's
		// setSelection: does not clamp, and its selectionRect is a
		// read-only rect derived from the frame selection, so the
		// "tiny bit larger" fudge becomes a 10% wider frame
		// selection:
		{
		[super setSelection:firstSample size:(int)(sampleCount*1.1)];
			// as good as can be done...
			// this makes the selection a tiny bit larger
		}
	else [super setSelection:firstSample size:sampleCount];
	//return self;
}



- (void)selectAll:(id)sender
// a fixed version of selectAll which sets the proper selected area
// POSSIBLE BUG ALERT:  NeXT's stuff may depend on the broken selectAll!

{
	[self setSelection:0 size:[[self sound] lengthInSampleFrames]];
}


- set:
	(BOOL) displayXAxis:
	(BOOL) displayYAxis:
	(BOOL) displayLabels:
	(BOOL) displayZeroLine:
	(int) majorTickSpacing:
	(float) minorTickSpacing:
	(int) minorTickSpacingFormat:
	(int) yDisplayFormat:
	(BOOL) scrollToReflectPlaying
	
	// Sets these values...
	
	
	{
	id theScrollView = [self scrollView];
	
	[self setupRuler];	

	display_x_axis_marks=displayXAxis;
	[theScrollView setRulersVisible:displayXAxis];
	display_y_axis_grid=displayYAxis;
	display_labels=displayLabels;
	display_zero_line=displayZeroLine;
	scroll_to_reflect_playing=scrollToReflectPlaying;
	
	// first set the default spacing in case this spacing is invalid
	major_tick_spacing=5;
	if (minorTickSpacingFormat==
		MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT) minor_tick_spacing=10.0;
	else if (minorTickSpacingFormat==
		MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES) minor_tick_spacing=1000;
	else if (minorTickSpacingFormat==
		MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SECONDS) minor_tick_spacing=1;
	
	// then change to the user's spacing if his spacing is acceptable
	if (majorTickSpacing>0)
		major_tick_spacing=majorTickSpacing;
	if ((minorTickSpacing>0.0&&
		(minorTickSpacingFormat!=
		MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES)) ||
	    (minorTickSpacing>=1.0&&
		(minorTickSpacingFormat==
		MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES)))
		minor_tick_spacing=minorTickSpacing;
	
	minor_tick_spacing_format=minorTickSpacingFormat;
	y_display_format=yDisplayFormat;
	[self _adjustBounds];
	[self display];
	return self;
	}
	
- (BOOL) xAxisDisplayed
	{
	return display_x_axis_marks;
	}

- (BOOL) yAxisDisplayed
	{
	return display_y_axis_grid;
	}

- (BOOL) zeroLineDisplayed
	{
	return display_zero_line;
	}

- (BOOL) labelsDisplayed
	{
	return display_labels;
	}

- (BOOL) scrollToReflectPlaying
	{
	return scroll_to_reflect_playing;
	}

- (int) majorTickSpacing
	{
	return major_tick_spacing;
	}

- (float) minorTickSpacing
	{
	return minor_tick_spacing;
	}

- (int) minorTickSpacingFormat
	{
	return minor_tick_spacing_format;
	}

- (int) yDisplayFormat
	{
	return y_display_format;
	}


- scrollToSelection:sender
	// scrolls if there's room to do so
	{
	int first_sample,number_of_samples;
	int total_samples;
	NSRect bounds_rect;
	NSRect visible_rect;
	NSPoint scroll_point;
	id currentScrollView=[self scrollView];
	
	if (currentScrollView==NULL) return NULL;		// not in scrollView!
	
	total_samples=[[self sound] lengthInSampleFrames];
	[self getSelection:&first_sample size:&number_of_samples];
	bounds_rect = [self bounds];		// get new bounds information if any
	visible_rect = [self visibleRect];
	
	if (!total_samples) total_samples=1;		// kills divide-by-zero
	
		scroll_point.x= ((bounds_rect.size.width*
		(double)first_sample)/(double) total_samples);
	scroll_point.y= (bounds_rect.origin.y);
	if (scroll_point.x+visible_rect.size.width>
		[self bounds].size.width) 
			scroll_point.x=[self bounds].size.width-visible_rect.size.width;
			
	[self scrollPoint:scroll_point];
	[currentScrollView reflectScrolledClipView:(NSClipView*)[self superview]];   //***** Type cast ?!!?
	return self;
	}
	
- scrollToSample:(int) samp
	// scrolls to samp if there's room to do so.
	{
	int first_sample;
	int total_samples;
	NSRect bounds_rect;
	NSRect visible_rect;
	NSPoint scroll_point;
	id currentScrollView=[self scrollView];
	
	if (currentScrollView==NULL) return NULL;		// not in scrollView!
	
	total_samples=[[self sound] lengthInSampleFrames];
	first_sample=samp;
	bounds_rect = [self bounds];		// get new bounds information if any
	visible_rect = [self visibleRect];
	
	if (!total_samples) total_samples=1;		// kills divide-by-zero
	
	scroll_point.x= ((bounds_rect.size.width*
		(double)first_sample)/(double) total_samples);
	scroll_point.y= (bounds_rect.origin.y);
	if (scroll_point.x+visible_rect.size.width>
		[self bounds].size.width) 
			scroll_point.x=[self bounds].size.width-visible_rect.size.width;
			
	[self scrollPoint:scroll_point];
	[currentScrollView reflectScrolledClipView: (NSClipView*)[self superview]];   //***** Type cast ?!!?
	return self;
	}
	
- (int)scrollSample
	// returns the current scrolled sample (leftmost)
	{
	int firstViewSample;
	NSRect visibleRect;
	double ReductionFactor;
	
	ReductionFactor= (double) [self reductionFactor];
	visibleRect = [self visibleRect];
	firstViewSample=(int)(visibleRect.origin.x*ReductionFactor);
	if ([self sound])
		if (firstViewSample>=[[self sound] lengthInSampleFrames])
			firstViewSample=[[self sound] lengthInSampleFrames]-1;
	if (firstViewSample<0) firstViewSample=0;
	return firstViewSample;
	}

- setPlayMark:(int)sample
	// relaying call to the ruler 
	{
	if (rulerView)
		[rulerView setPlayMark:sample];

	return self;
	}
	
	
	

- (double) _scrollValue							// a private method
	{
	NSSize content_size;
	id currentScrollView;
	currentScrollView=[self scrollView];
	
	if (currentScrollView==NULL) return 0;		// not in scrollView!
	
	content_size = [currentScrollView contentSize];
	
	return reduction_to_scroll
		( [self reductionFactor],
		  ((double)[[self sound] lengthInSampleFrames])
		  /(double)content_size.width);
	}
	


- _setScrollValue:(double) this_value		
					// private method. this_value must be between 1 and 0
	{
	NSSize content_size;
	double new_reduction_factor;
	int first_sample, number_of_samples;
	id currentScrollView=[self scrollView];
	
	if (currentScrollView==NULL) return NULL;		// not in scrollView!
	
	content_size = [currentScrollView contentSize];

	[self getSelection:&first_sample size:&number_of_samples];

	new_reduction_factor= scroll_to_reduction		
					// is this where the problem lies?
		( this_value,
		  ((double)[[self sound] lengthInSampleFrames])
		  /(double)content_size.width);
	
	if (new_reduction_factor!=-1.0)		// it's not an error
		{
		[self setReductionFactor:new_reduction_factor];
		[self setSelection:first_sample size: number_of_samples];
		return self;
		}
	else
		{
		[self setSelection:first_sample size: number_of_samples];
		return NULL;
		}
	}
	
	
	
- _zoomTo:(double) scroll_value					// a private method
	{
	id returnval;
	int first_sample, number_of_samples;
	[[self window] disableFlushWindow];
	[self getSelection:&first_sample size:&number_of_samples];
		
	if (scroll_value>1.0) scroll_value=1.0;
	if (scroll_value<0.0) scroll_value=0.0;
	returnval=[self _setScrollValue:scroll_value];
	[self setSelection:first_sample size: number_of_samples];
	[self display];
	[[self window] enableFlushWindow];
	[[self window] flushWindowIfNeeded];
	return returnval;
	}
	
- getZoomValueFrom:sender
	{
	return [self _zoomTo:[sender floatValue]];
	}
		
- (void)takeIntValueFrom:sender
	{
	int temp_play_mark=[sender intValue];
	id snd=[self sound];
	int samples;
	
	if (snd==NULL) samples=0;
	else samples=[snd lengthInSampleFrames];
	
	if (temp_play_mark>=0&&
		temp_play_mark<samples&&scroll_to_reflect_playing)
		{
		[self scrollToSample:temp_play_mark];
		[self setPlayMark:temp_play_mark];
		}
	else [self setPlayMark:-1];
}	
	
- zoomAllIn:this_soundview
	{
	[self _zoomTo:0.0];
	[self scrollToSelection:self];
	return self;
	}
	
	
- zoomAllOut:this_soundview
	{
	[self _zoomTo:1.0];
	[self scrollToSelection:self];
	return self;
	}
	

- zoomOutOneReduction:sender
	{
	id returnval=self;
	double scroll_value,reduction;
	int first_sample, number_of_samples;
	
	[[self window] disableFlushWindow];
	[self getSelection:&first_sample size:&number_of_samples];
	reduction=[self reductionFactor];
	[self setReductionFactor:(int)reduction+1];
	scroll_value=[self _scrollValue];
	
	if (scroll_value>1.0||scroll_value<0.0)	
		{
		if (scroll_value>1.0) scroll_value=1.0;
		if (scroll_value<0.0) scroll_value=0.0;
		returnval=[self _setScrollValue:scroll_value];
		}
	[self setSelection:first_sample size: number_of_samples];
	[self scrollToSelection:self];
	[[self window] enableFlushWindow];
	[[self window] flushWindowIfNeeded];
	return returnval;
	}


- zoomInOneReduction:sender
	{
	id returnval=self;
	double scroll_value;
	double reduction;
	int first_sample, number_of_samples;
	
	[[self window] disableFlushWindow];
	[self getSelection:&first_sample size:&number_of_samples];
	reduction=[self reductionFactor];
	if (reduction>=1.0) [self setReductionFactor:(int)reduction-1];
	scroll_value=[self _scrollValue];
	if (scroll_value>1.0||scroll_value<0.0)	
		{
		if (scroll_value>1.0) scroll_value=1.0;
		if (scroll_value<0.0) scroll_value=0.0;
		returnval=[self _setScrollValue:scroll_value];
		}
	[self setSelection:first_sample size: number_of_samples];
	[self scrollToSelection:self];
	[[self window] enableFlushWindow];
	[[self window] flushWindowIfNeeded];
	return returnval;
	}



- zoomToSelection:sender
	{
	int first_sample, number_of_samples;
	double reduction_factor;
	NSRect visible_rect;
	
	// Step 0:  Get preliminary information
	
	if (self==NULL) return NULL;
	[[self window] disableFlushWindow];	
	
	[self getSelection:&first_sample size:&number_of_samples];
	
	visible_rect = [self visibleRect];

	// Step 1:  Zoom to the right reduction
	
	reduction_factor=MISCSOUNDVIEW_round(
			((double) number_of_samples) / ((double) visible_rect.size.width));
	if (reduction_factor<1.0) reduction_factor=1.0;
	[self setReductionFactor: reduction_factor];
	[self setSelection:first_sample size: number_of_samples];

		
	// Step 2:  Move to the right spot
	
	[self scrollToSelection:self];

	// Step 3:  Update Information
	[self display];
	[[self window] enableFlushWindow];
	[[self window] flushWindowIfNeeded];
	return self;
	}
	
- (id)initWithCoder:(NSCoder *)aDecoder
	{
	[super initWithCoder:aDecoder];
	[aDecoder decodeValuesOfObjCTypes:"ifiii",	&display_x_axis_marks,&minor_tick_spacing,
								&minor_tick_spacing_format,&major_tick_spacing,
								&display_labels];

	[aDecoder decodeValuesOfObjCTypes:"iiii",	&display_y_axis_grid,&display_zero_line,
								&y_display_format,&scroll_to_reflect_playing];

        rulerView = [[MiscSoundViewRuler alloc] init];

	return self;
	}
	
- (void)encodeWithCoder:(NSCoder *)aCoder
	{
	[super encodeWithCoder:aCoder];
	[aCoder encodeValuesOfObjCTypes:"ifiii",&display_x_axis_marks,&minor_tick_spacing,
								&minor_tick_spacing_format,&major_tick_spacing,
								&display_labels];
	[aCoder encodeValuesOfObjCTypes:"iiii",	&display_y_axis_grid,&display_zero_line,
								&y_display_format,&scroll_to_reflect_playing];
}


- (void)setScrollView:(id)theScrollView
{
scrollView = theScrollView;
}


-(id)scrollView
{
if(scrollView == nil)
        [self autoSetScrollView];

return scrollView;
}


-(BOOL)autoSetScrollView
{
id tmpScrollView = [[self superview] superview];

if((tmpScrollView !=nil)  && ([tmpScrollView respondsToSelector:@selector(setHasHorizontalRuler:)] ) )
	{
	scrollView = tmpScrollView;
	return YES;	// success
	}
return NO;	// failure 
}


- (void)setupRuler
{

id theScrollView = [self scrollView];

if(theScrollView != nil)
	{
	[theScrollView setHasHorizontalRuler:YES];
	[theScrollView setHorizontalRulerView:(NSRulerView *)rulerView];
	[theScrollView setRulersVisible:display_x_axis_marks];

	[self adjustBounds:self];
	}
}

- (void)awakeFromNib
	{
	[self setupRuler];
	}
	
- toggleXAxisDisplayed:sender
	{
	id theScrollView = [self scrollView];
	
	[self setupRuler];

	[theScrollView setRulersVisible:![theScrollView rulersVisible] ];

	display_x_axis_marks=!display_x_axis_marks;
	return [self adjustBounds:self];
	}
	
- toggleYAxisDisplayed:sender	
	{
	display_y_axis_grid=!display_y_axis_grid;
	[self display];
	return self;
	}

- toggleLabelsDisplayed:sender
	{
	display_labels=!display_labels;
	[self display];
	return self;
	}

- toggleZeroLineDisplayed:sender
	{
	display_zero_line=!display_zero_line;
	[self display];
	return self;
	}
	
- toggleScrollToReflectPlaying:sender
	{
	scroll_to_reflect_playing=!scroll_to_reflect_playing;
	return self;
	}

- (NSString *)inspectorClassName
        {
	return @"MiscSoundViewInspector";
        }

- (void)cut:(id)sender;
	{
	double scroll_value;

	// Call super
	[super cut:sender];

	// Verify display after cut
        scroll_value=[self _scrollValue];
        if (scroll_value>1.0) 
        	{
        	//[self _zoomTo:1.0];			// Not in scroll view,
        	[self scrollToSelection:self];		// white space has appeared!
        	}
	} 

- (void)delete:(id)sender;
        {
        double scroll_value;

        // Call super
        [super delete:sender];

        // Verify display after cut
        scroll_value=[self _scrollValue];
        if (scroll_value>1.0)
                {
                //[self _zoomTo:1.0];			// Not in scroll view,
                [self scrollToSelection:self];		// white space has appeared!
                }
        } 

@end
