/*
MiscSoundViewRuler
Version 2.0
Copyright (c) 1998 by Jerome Genest
parts by Sean Luke Copyright(c)  1995
Donated to the MiscKit

Permission to use, copy, modify, and distribute this material
for any purpose and without fee, under the restrictions as noted
in the MiscKit copyright notice, is hereby granted, provided that
the MiscKit copyright notice and this permission notice
appear in all source copies, and that the authors names shall not
be used in advertising or publicity pertaining to this
material without the specific, prior written permission
of the author.  JEROME GENEST  AND SEAN O. LUKE MAKES NO REPRESENTATIONS
ABOUT THE ACCURACY OR SUITABILITY OF THIS MATERIAL FOR ANY PURPOSE.
IT IS PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
*/

/* Warning :
	The MiscSoundViewRuler does not fit entirely in the NSRulerView model
	It is designed to be used only with a MiscSoundView as an horizontal ruler
	Among other things, it ignores the current measurement unit as set by 
	"-setMeasurementUnits:" It can display the ticks and labels for a MiscSoundView 
	in samples, percent or second, using the MiscSoundView s "set:" method.
	All the behaviours of the ruler should be controlled via the MiscSoundView.
	The ruler should work transparently and the need to directly use this class 
	is very unlikely.
*/

#import "MiscSoundViewRuler.h"

@implementation MiscSoundViewRuler

- initWithFrame:(NSRect)frameRect
{
id returnval=[super initWithFrame:frameRect];

// ensure a minimal rule thickness

if ([self ruleThickness] < MISCSOUNDVIEW_MINIMUM_RULER_HEIGHT)
        [super setRuleThickness:MISCSOUNDVIEW_MINIMUM_RULER_HEIGHT];

old_play_mark=-1;
play_mark=-1;
only_change_play_mark=NO;
return returnval;
}

// This is where the ticks and labels are drawn

- (void)drawHashMarksAndLabelsInRect:(NSRect)rects
{
BOOL display_major_ticks;
BOOL enough_room_for_labels;
BOOL display_minor_ticks;
float tick_height;
int startsample,endsample,xx;
int numberOfSamples;
double scale_factor;
char tempstring[20],maxWidthString[20];
float print_value;
float xStringWidth;
// Retreiving the parent soundView, the sound
// and all relevant information

id sndView = [[self scrollView] documentView];
id sound = [(SndView*)sndView sound];					// TypeCast for OS X server
int reductionFactor = [sndView reductionFactor];
int true_sample_count=[[(SndView*)sndView sound] lengthInSampleFrames];	// TypeCast for OS X server
float minor_tick_spacing = [sndView minorTickSpacing];			// Minor Tick Spacing
int minor_tick_spacing_format = [sndView minorTickSpacingFormat];	// Tick Format
int major_tick_spacing = [sndView majorTickSpacing];		// Number of minor ticks per major tick
BOOL display_labels = [sndView labelsDisplayed];		// Draw label information with ruler
id docView = [[self scrollView] documentView];
NSRect convertedDocBounds = [self convertRect:[docView bounds] fromView:docView];
NSRect sndViewRects = [self convertRect:rects toView:docView];

// Figure out the scaling factor:

scale_factor=[self bounds].size.height/[self frame].size.height;

tick_height=[self ruleThickness]/2; // tick height = half the height of the region reserved for ticks & labels

if  (minor_tick_spacing_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES) 	// display in samples
      {
       numberOfSamples=(int)minor_tick_spacing;
      }

else if (minor_tick_spacing_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT) // display in percentage
      {
      numberOfSamples=(int)
	(minor_tick_spacing/100.0*[[(SndView*)sndView sound] lengthInSampleFrames]);	// TypeCast for OS X server
      }
else   										// display in seconds
      {
      numberOfSamples=(int)(minor_tick_spacing*[[(SndView*)sndView sound] samplingRate]);	// TypeCast for OS X server
      }

if (!numberOfSamples) numberOfSamples=1;		// for divide-by-zero	

// are start and stop sample calcultated correctly ?
// If we are drawing outside the clip rgn, this waste precious processing time

startsample=(((int) (sndViewRects.origin.x*reductionFactor))/numberOfSamples)*numberOfSamples;

                                // note the integer division above!!!!  This
                                // does automatic rounding properly...

endsample=((int)(sndViewRects.size.width+sndViewRects.origin.x))*reductionFactor;


/// Calculating labels width

if (minor_tick_spacing_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES) // display in samples
        print_value=(float)endsample;
else if (minor_tick_spacing_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT)// display in percentage
        print_value=((float)endsample)/((float)[sound lengthInSampleFrames])*100;
else					// display in seconds
        print_value=((float)endsample)/(float)[sound samplingRate];	

if (minor_tick_spacing_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES)
	sprintf(maxWidthString, " %d", (int)print_value);	// use int value
else if (minor_tick_spacing_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT)
	sprintf(maxWidthString, " %d", MISCSOUNDVIEW_round(print_value));// use rounded int value
else sprintf(maxWidthString, " %.3f", print_value);	// use float value

// The 1998 code drew the ruler labels with PSselectfont("Helvetica",9)
// and measured them with PSstringwidth().  GNUstep's PostScript
// interface provides no PSselectfont/PSstringwidth, so the labels are
// drawn with NSString drawing in the same 9pt font:
NSFont *tick_label_font=[NSFont fontWithName:@"Helvetica" size:9.0];
if (tick_label_font==nil) tick_label_font=[NSFont systemFontOfSize:9.0];
NSDictionary *tick_label_font_attr=[NSDictionary dictionaryWithObjectsAndKeys:
	tick_label_font, NSFontAttributeName,
	nil];
{
NSSize tick_label_width;
tick_label_width = [[NSString stringWithUTF8String:maxWidthString]
	sizeWithAttributes:tick_label_font_attr];
xStringWidth=tick_label_width.width;
}


// What should be displayed ?

display_minor_ticks=
	(BOOL)(((float)numberOfSamples)/reductionFactor
	>=MISCSOUNDVIEW_TICK_MINIMUM_SPACING);
display_major_ticks=
	(BOOL)(((float)numberOfSamples)*major_tick_spacing/reductionFactor
	>=MISCSOUNDVIEW_TICK_MINIMUM_SPACING);
enough_room_for_labels=
	(BOOL)(((float)numberOfSamples)*major_tick_spacing/reductionFactor
        >=xStringWidth);//MISCSOUNDVIEW_TICK_MINIMUM_SPACING_WITH_LABELS);


if (!only_change_play_mark&&true_sample_count)
    {
	// Draw ruler lines
	PSsetlinewidth(0);
	PSsetgray(NSBlack);
	PSmoveto(rects.origin.x, 1);
        PSmoveto(rects.origin.x, [self baselineLocation]);
	PSrlineto(rects.size.width, 0);
    }

PSstroke();

// Next, draw new play-mark

old_play_mark=play_mark;

if (old_play_mark!=-1&&true_sample_count)	// don't draw if no samples
        {
           PSsetgray(NSBlack);
           PSmoveto(old_play_mark/reductionFactor+convertedDocBounds.origin.x,
		[self baselineLocation] + 2*tick_height - MISCSOUNDVIEW_PLAY_MARK_HEIGHT*scale_factor);
           PSrlineto(0,2*scale_factor);
           PSrmoveto(-1,-1*scale_factor);
           PSrlineto(2,0);
         }
PSstroke();

// finally, draw the ticks and add the labels

if (!only_change_play_mark&&true_sample_count)
    {
    // here we draw the label equal to or directly to the left of
    // startsample, to fix a little bug in drawing that comes up
    // when scrolling.

    xx=(startsample/(numberOfSamples*major_tick_spacing))*(numberOfSamples*major_tick_spacing);
                                                               // note integer division!!!
    
    PSmoveto(((float)xx)/reductionFactor+convertedDocBounds.origin.x,[self baselineLocation]);   

    PSrmoveto(0,tick_height*scale_factor);
    if (display_labels&&enough_room_for_labels)
        {
        if (minor_tick_spacing_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES)
            print_value=(float)xx;
        else if (minor_tick_spacing_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT)
            print_value=((float)xx)/((float)[sound lengthInSampleFrames])*100;
        else 
	    print_value=((float)xx)/(float)[sound samplingRate];
        if (minor_tick_spacing_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES)
        	sprintf(tempstring, " %d", (int)print_value);	// use int value
	else if (minor_tick_spacing_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT)
                 sprintf(tempstring, " %d",MISCSOUNDVIEW_round(print_value));
        else 
		sprintf(tempstring, " %.3f", print_value);	// use float value

        // 1998: PSgsave/PSinitmatrix/PSrmoveto(0,-4)/PSselectfont/PSshow/
        // PSgrestore - draw the label 4 points below the tick mark.
        [[NSString stringWithUTF8String:tempstring]
        	drawAtPoint:NSMakePoint(((float)xx)/reductionFactor+convertedDocBounds.origin.x,
        			[self baselineLocation]+tick_height*scale_factor-4.0)
        	withAttributes:tick_label_font_attr];
        }

      // end bug fix.  We continue, now drawing the ticks
      // and adding labels...

      if (minor_tick_spacing!=0.0)
      for (xx=startsample;xx<=endsample;xx+=numberOfSamples)
           {
           // Prepare the ruler for labelling

           if (display_major_ticks&&major_tick_spacing&&(!(xx%(numberOfSamples*major_tick_spacing))))
                {
                PSsetgray(NSBlack);
          	PSmoveto(((float)xx)/reductionFactor+convertedDocBounds.origin.x,[self baselineLocation]);
                PSrlineto(0,tick_height*scale_factor);
                PSgsave();
                PSstroke();
                PSgrestore();	// preserves path and (more importantly)// currentpoint
                                // And Add Label

                if (display_labels&&enough_room_for_labels)
                     {
                      if (minor_tick_spacing_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES) 
								// display in samples
			print_value=(float)xx;
                      else if (minor_tick_spacing_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT)
								// display in percentage
                        print_value=((float)xx)/((float)[sound lengthInSampleFrames])*100;
		      else					// display in seconds
                        print_value=((float)xx)/(float)[sound samplingRate];	
                      if (minor_tick_spacing_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES)
                            sprintf(tempstring, " %d", (int)print_value);	// use int value
		      else if (minor_tick_spacing_format==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT)
                            sprintf(tempstring, " %d", MISCSOUNDVIEW_round(print_value));// use rounded int value
		      else sprintf(tempstring, " %.3f", print_value);	// use float value
              // 1998: PSgsave/PSinitmatrix/PSrmoveto(0,-4)/PSselectfont/
              // PSshow/PSgrestore - draw the label 4 points below the tick.
              [[NSString stringWithUTF8String:tempstring]
                  drawAtPoint:NSMakePoint(((float)xx)/reductionFactor+convertedDocBounds.origin.x,
                      [self baselineLocation]+tick_height*scale_factor-4.0)
                  withAttributes:tick_label_font_attr];
                     }
                 }
           else
                 {
                 if (display_minor_ticks)
                      {
                      PSsetgray(NSBlack);
                      PSmoveto(((float)xx)/reductionFactor+convertedDocBounds.origin.x,[self baselineLocation]);
                      PSrlineto(0,tick_height/2*scale_factor);	 // minor ticks are 1/2 height of major ticks

                      PSstroke();
                      }
                  }
           PSnewpath(); // deletes path saved when drawing major ticks.	
           }
    }
}


// Sets the play mark position
// Called by the MiscSoundView corresponding method 

-setPlayMark:(int)theMark
{
NSRect tempRect;

tempRect = [self frame];

// set up a temp rect corresponding to the play mark region
tempRect.origin.x =0;
tempRect.origin.y = [self baselineLocation] + 3*[self ruleThickness]/4 + 1;
tempRect.size.height = [self ruleThickness]/4;

old_play_mark=play_mark;
play_mark=(float)theMark;

// Tell the drawing code to display only the play mark
// this saves a lot of operaitons so the playmark is moves more smootly
only_change_play_mark=YES;

// Update the ruler only in the playmark region
[self displayRect:tempRect];

//draw everything on next update
only_change_play_mark=NO;

return self;
}



// return whether we should draw only the play mark
// for the benefit of the MiscSoundView drawing code

-(BOOL)onlyChangePlayMark
{
return only_change_play_mark;
}

// Overridden to ensure a minimal rule thickness
// This is done to obtain a nice display of ticks and labels

- (void)setRuleThickness:(float)thickness
{
if (thickness < MISCSOUNDVIEW_MINIMUM_RULER_HEIGHT)
	thickness = MISCSOUNDVIEW_MINIMUM_RULER_HEIGHT;
[super setRuleThickness:thickness];
}

@end
