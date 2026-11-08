/*

 MiscSoundView
 Version 2.01
 Copyright (c) 1995 by Sean Luke
 Copyright (c) 1998 by Jerome Genest, Frederic Bourget from Daffy Software
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

#import <SndKit/SndKit.h>
#import <AppKit/AppKit.h>

// Defines

#define MISCSOUNDVIEW_MINIMUM_RULER_HEIGHT 25  			// minimum
#define MISCSOUNDVIEW_PLAY_MARK_HEIGHT 4

#define MISCSOUNDVIEW_TICK_MINIMUM_SPACING 2.0
#define MISCSOUNDVIEW_TICK_MINIMUM_SPACING_WITH_LABELS 40.0

#define MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES 1
#define MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SECONDS 0
#define MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT 2

#define MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_DECIBEL 1
#define MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_SIXTEEN 2
#define MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTY 3
#define MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTYFOUR 4

// CONVENIENCE FUNCTIONS

double scroll_to_reduction (double scrollValue, double ratio);
int MISCSOUNDVIEW_round(float x);
double reduction_to_scroll (double reduction, double ratio);

@interface MiscSoundView:SndView
{
	id rulerView;
	id scrollView;
	// X Axis information
	
	BOOL display_x_axis_marks;	// Display the Ruler
	float minor_tick_spacing;	// Minor Tick Spacing
	int minor_tick_spacing_format;	// Tick Format
	int major_tick_spacing;		// Number of minor ticks per major tick
	BOOL display_labels;		// Draw label information with ruler

	// Y Axis information
	
	BOOL display_y_axis_grid;	// display the amplitude
	BOOL display_zero_line;		// display the zero line
	int y_display_format;		// amplitude format

	// Scrolling
			
	BOOL scroll_to_reflect_playing;	// Scroll to reflect playing
		
	}


// OVERRIDDEN TO FIX BUGS IN SOUNDVIEW

- (void) getSelection:(int *)firstSample size:(int *)sampleCount;
- (void) setSelection:(int)firstSample size:(int)sampleCount;
- (void)selectAll:(id)sender;

- (void)cut:(id)sender;
- (void)delete:(id)sender;

// UTILITY METHODS

- (void)setScrollView:(id)theScrollView; //
-(id)scrollView;			// return the scrollview,tries 							// autoSetScrollView if nil
-(BOOL)autoSetScrollView;		// Gets  the scroll as the superview 
					// of the superview
- (void)setupRuler;			// set the ruler
- scrollToSelection:sender;		// Tries to scroll to place selection
					// starting at far left of visible rect
- scrollToSample:(int)samp;		// Tries to scroll to place sample in
					// far left of visible rect
- (int) scrollSample;			// Sample at far left of visible rect
- setPlayMark:(int)sample;		// Erases the old play mark and draws
					// a new one at sample if the ruler is 
					// displayed.  If sample is -1, no new
					// play mark is drawn but old one is
					// erased.
- zoomAllIn:sender;			// Scales to maximum detail, scrolls to
					// selection
- zoomAllOut:sender;			// Scales to minimum detail, scrolls to
					// selection
- zoomInOneReduction:sender;		// Scales to one more level of detail,
					// scrolls to selection
- zoomOutOneReduction:sender;		// Scales to one less level of detail,
					// scrolls to selection
- zoomToSelection:sender;		// Scales and scrolls to selection
- getZoomValueFrom:sender;		// Scales to a value between 0 and 1,
					// and scrolls to selection
- (void)takeIntValueFrom:sender;	// Sets the play mark to the int value
					// of sender.  Used in conjunction with
					// a SoundTracker on the SoundView,
					// tracking on SAMPLES.
- adjustBounds:sender;			// adjusts the SoundView's bounds so
					// the ruler will fit within its parent
					// ScrollView.


// SETTING VALUES		(should be done immediately after initFrame)

- set:
	(BOOL) displayXAxis:
	(BOOL) displayYAxis:
	(BOOL) displayLabels:
	(BOOL) displayZeroLine:
	(int) majorTickSpacing:
	(float) minorTickSpacing:
	(int) minorTickSpacingFormat:
	(int) thisYDisplayFormat:
	(BOOL) scrollToReflectPlaying;

// TO DEMO SOUNDVIEW 

- toggleXAxisDisplayed:sender;
- toggleYAxisDisplayed:sender;
- toggleLabelsDisplayed:sender;
- toggleZeroLineDisplayed:sender;
- toggleScrollToReflectPlaying:sender;

// QUERYING VALUES	
	
- (BOOL) xAxisDisplayed;
- (BOOL) yAxisDisplayed;
- (BOOL) zeroLineDisplayed;
- (BOOL) labelsDisplayed;
- (BOOL) scrollToReflectPlaying;
- (int) majorTickSpacing;
- (float) minorTickSpacing;
- (int) minorTickSpacingFormat;
- (int) yDisplayFormat;

- (void)awakeFromNib; 
@end
