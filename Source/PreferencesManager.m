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

  PreferencesManager.[h|m]
  Sean Luke
  
  PreferencesManager handles the Preferences window, and provides access to
  all preferences information for Resound.
  
  ****************************************************************************/


#import "PreferencesManager.h"
#import "ResoundNibs.h"
#import "ResoundMiscSoundView.h"
#import <AppKit/AppKit.h>
#import <string.h>
#import <stdio.h>

@implementation PreferencesManager


/*** init
  Initializes the Preference Manager
*/

- init

    {
    NSDictionary* dict=
    [NSDictionary dictionaryWithObjectsAndKeys:
        @"YES", @"MinMaxDisplay",
        @"YES", @"ZoomIn",
        @"NO", @"DisplayTicks",
        @"NO", @"DisplayZeroLine",
        @"NO", @"DisplayAmplitude",
        @"2", @"AmplitudeFormat", 					
        @"1", @"TickFormat", 						
        @"1000", @"MinorTickValue",
        @"10", @"MajorTickValue",
        @"NO", @"PlayOnOpen",
        @"NO", @"ConvertOnOpen",
        @"NO", @"Backup",
        @"NO", @"ScrollToReflectSound",
        nil];

    id returnval=[super init];
    preferencesPanelLoaded=0;

    [[NSUserDefaults standardUserDefaults] registerDefaults:
        dict];

    [self performPreferences];
    return returnval;
    }





/*** SavePreferences
  Saves out all preferences.
*/



- savePreferences

    {
    NSString* title;
    NSUserDefaults* defaults=[NSUserDefaults standardUserDefaults];
    // set fields to proper values
    
    [majorTicksField setIntValue:[majorTicksField intValue]];
    [minorTicksField setFloatValue:[minorTicksField floatValue]];
    if ([majorTicksField intValue]<1) [majorTicksField setIntValue:1];
    if ([minorTicksField floatValue]<=0.0) [minorTicksField setFloatValue:1.0];
    
    // Write defaults
    
    [defaults setBool: [backupButton state] forKey: @"Backup"];
    [defaults setBool: [playOnOpenButton state] forKey: @"PlayOnOpen"];
    [defaults setBool: [convertOnOpenButton state] forKey: @"ConvertOnOpen"];
    [defaults setBool: [minMaxDisplayButton state] forKey: @"MinMaxDisplay"];
    [defaults setBool: [zoomedInButton state] forKey: @"ZoomIn"];
    [defaults setBool: [displayTicksButton intValue] forKey: @"DisplayTicks"];
    [defaults setBool: [scrollToReflectSoundButton intValue] forKey: @"ScrollToReflectSound"];
    [defaults setBool: [displayZeroLineButton intValue] forKey: @"DisplayZeroLine"];
    [defaults setBool: [displayAmplitudeButton intValue] forKey: @"DisplayAmplitude"];
    [defaults setFloat: [minorTicksField floatValue] forKey: @"MinorTickValue"];
    [defaults setInteger: [majorTicksField intValue] forKey: @"MajorTickValue"];
    
    title=[amplitudeButton title];
    if ([title isEqualToString: @"16-Point"])
        [defaults setInteger: MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_SIXTEEN forKey: @"AmplitudeFormat"];
    else if ([title isEqualToString: @"20-Point"])
        [defaults setInteger: MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTY forKey: @"AmplitudeFormat"];
    else if ([title isEqualToString: @"24-Point"])
        [defaults setInteger: MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTYFOUR forKey: @"AmplitudeFormat"];
    else 			// decibel
        [defaults setInteger: MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_DECIBEL forKey: @"AmplitudeFormat"];

    title=[minorTicksFormatButton title];
    if ([title isEqualToString: @"Samples"])
        [defaults setInteger: MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES forKey: @"TickFormat"];
    else if ([title isEqualToString: @"Seconds"])
        [defaults setInteger: MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SECONDS forKey: @"TickFormat"];
    else 			// Percent
        [defaults setInteger: MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT forKey: @"TickFormat"];

    [self performPreferences];
    return self;
    }





/*** PerformPreferences
  Sets the Preferences Panel to current preferences settings.
*/

- performPreferences
{
    // Then read in the defaults and adjust the buttons, etc., on the
    // preferences panel appropriately.

    float x; int y;

    NSUserDefaults* defaults=[NSUserDefaults standardUserDefaults];
    [backupButton setIntValue:[defaults boolForKey: @"Backup"]];
    [playOnOpenButton setIntValue:[defaults boolForKey: @"PlayOnOpen"]];
    [convertOnOpenButton setIntValue:[defaults boolForKey: @"ConvertOnOpen"]];
    if ([defaults boolForKey: @"ZoomIn"])
        [zoomMatrix selectCell:zoomedInButton];
    else
        [zoomMatrix selectCell:zoomedOutButton];

    if ([defaults boolForKey: @"MinMaxDisplay"])
        [attributesMatrix selectCell:minMaxDisplayButton];
    else
        [attributesMatrix selectCell:oscilliscopicDisplayButton];

    [displayTicksButton setIntValue: [defaults boolForKey: @"DisplayTicks"]];
    [scrollToReflectSoundButton setIntValue: [defaults boolForKey: @"ScrollToReflectSound"]];
    [displayAmplitudeButton setIntValue: [defaults boolForKey: @"DisplayAmplitude"]];
    [displayZeroLineButton setIntValue: [defaults boolForKey: @"DisplayZeroLine"]];

    x=[defaults floatForKey: @"MinorTickValue"];
    if (x<=0.0) x=1.0;
    [minorTicksField setFloatValue:x];

    y=[defaults floatForKey: @"MajorTickValue"];
    if (y<1) y=1;
    [majorTicksField setIntValue:y];

    y=[defaults integerForKey: @"AmplitudeFormat"];
    if (y==MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTY)
        [amplitudeButton setTitle: @"20-Point"];	
    else if (y==MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTYFOUR)
	    [amplitudeButton setTitle: @"24-Point"];					
    else if (y==MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_SIXTEEN)
        [amplitudeButton setTitle: @"16-Point"];
    else				// decibel
		[amplitudeButton setTitle: @"Decibel"];					


    y=[defaults integerForKey: @"TickFormat"];
    if (y==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT)
        [minorTicksFormatButton setTitle: @"Percent"];	
    else if (y==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SECONDS)
        [minorTicksFormatButton setTitle: @"Seconds"];	
    else
        [minorTicksFormatButton setTitle: @"Samples"];

    return self;
}



/*** SoundComingIn
  Performs the preferences.  Called initially from the FileManager when sound windows
  have begun being formed.
*/

- soundComingIn						
// A nicer way for the FileManager to get the Preferences to know that the
// user has started working on sounds.  Use this as you like.
    {
    [self performPreferences];
    return self;
    }




/*** ZoomIn
  Returns whether or not sounds begin zoomed in.
*/

- (BOOL) zoomIn
    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey: @"ZoomIn"];
    }



/*** MinMaxDisplay
  Returns the default Display format for SoundViews.
*/

- (int) minMaxDisplay
    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey: @"MinMaxDisplay"])
        return NX_SOUNDVIEW_MINMAX;
    else return NX_SOUNDVIEW_WAVE;
    }

/*** backup
  Returns true if Resound backs up sounds by default.
*/

- (BOOL) backup
    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey: @"Backup"];
    }

/*** playOnOpen
  Returns true if Resound plays sounds on open by default.
*/
- (BOOL) playOnOpen
    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey: @"PlayOnOpen"];
    }

/*** convertOnOpen
  Returns true if Resound converts sounds to 22KHz on auto-open by default.
*/
- (BOOL) convertOnOpen
    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey: @"ConvertOnOpen"];
    }

/*** displayTicks
  Returns true if Resound displays ticks by default.
*/
- (BOOL) displayTicks
    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey: @"DisplayTicks"];
    }

/*** scrollToReflectSound
  Returns true if Resound scrolls to reflect sound playing by default.
*/
- (BOOL) scrollToReflectSound
    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey: @"ScrollToReflectSound"];
    }

/*** displayZeroLine
  Returns true if Resound displays the zero line by default.
*/
- (BOOL) displayZeroLine
    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey: @"DisplayZeroLine"];
    }

/*** displayAmplitude
  Returns true if Resound displays amplitude lines by default.
*/
- (BOOL) displayAmplitude
    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return 	[defaults boolForKey: @"DisplayAmplitude"];
    }

/*** amplitudeFormat
  Returns the default amplitude format.
*/
- (int) amplitudeFormat
    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    int y=[defaults integerForKey: @"AmplitudeFormat"];
    if (y==MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTY)
        return MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTY;
    else if (y==MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTYFOUR)
        return MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_TWENTYFOUR;
    else if (y==MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_SIXTEEN)
        return MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_SIXTEEN;
    else return MISCSOUNDVIEW_YAXIS_DISPLAY_FORMAT_DECIBEL;
    }


/*** minorTickFormat
  Returns the default minor tick format.
*/

- (int) minorTickFormat
    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    int y=[defaults integerForKey: @"TickFormat"];
    if (y==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT)
        return MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_PERCENT;
    else if (y==MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SECONDS)
        return MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SECONDS;
    else return MISCSOUNDVIEW_XAXIS_SPACING_FORMAT_SAMPLES;
    }

/*** minorTickValue
  Returns the default minor tick value.
*/

- (float) minorTickValue
    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    float x=[defaults floatForKey: @"MinorTickValue"];
    if (x<=0.0) x=1.0;
    return x;
    }

/*** majorTickValue
  Returns the default major tick value.
*/

- (int) majorTickValue
    {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    int y=[defaults floatForKey: @"MajorTickValue"];
    if (y<1) y=1;
    return y;
    }





/*** PreferencesOkayed:sender
  Saves the preferences.  Called when the user presses the Okay button.
*/

- preferencesOkayed:sender
    {
    [self savePreferences];
    // [preferencesPanel close];   // I *really* don't like closing the panel
    return self;
    }



/*** StartPreferencesPanel:sender
  Brings up the Preferences Panel.  Called by a menu item.
*/


- startPreferencesPanel:sender
    {
    if (!preferencesPanelLoaded)
	{
        [ResoundNibs loadNibNamed: @"Preferences" owner:self];
        preferencesPanelLoaded=1;
	}
    
    [self performPreferences];
    [preferencesPanel makeKeyAndOrderFront:self];
    return self;
    }




@end
