/*
	EnvelopeModule.m
	A simple sound enveloping module for Resound
	1.0, 1995-01-29, andrew abernathy
*/


#import "EnvelopeModule.h"
#import "ResoundNibs.h"
#import <SoundKit/SoundKit.h>
#import <AppKit/AppKit.h>
#import "ModuleSoundView.h" 


#define MAX_CHANNELS	2		// max number of channels we support
#define LOTS_OF_SAMPLES	((long) 400000)	// number of samples we consider lots


@implementation	EnvelopeModule


/*
- init

Here we set up our ModuleMenuNode - a node which gives us an entry point into Resound's Modules menu.  rootModuleMenuNode is an instance variable we inherit from the Module class - this is our menu "tree" off of which we build.  We only need one menu item, so we create a single menu node.  We give it a name - the text that will appear on our menu item.  We give it a receiver - ourself - so that we will receive it's target message.  We assign a message to it, in this case, a message to display our control panel.  Also, we tell it that it has no members (if we wanted a submenu, we would add other nodes here).  Finally, we
tell our menu tree that it only has one member (menu item), and that member is our newly created menu node.
*/

- init
{
	id			returnVal  = [super init];
	ModuleMenuNode *	envelopeNode  = [[ModuleMenuNode alloc] initLeafNode:@"Envelope":self:@selector(showEnvelopePanel:)];
	
	[rootModuleMenuNode addSubmenu:envelopeNode];
	
	return returnVal;
}


/*
- soundDidChange

We receive this message when the current sound has changed - a different or new sound window has become the main window, the current sound has been converted to a new format, etc.  We pass the message up to allow our superclass to do anything it wants.  We then examine the current sound to see how many channels it has.  If it has more than one channel we assume it is stereo, and we enable the channel checkboxes so that any enveloping may be applied to only one channel if desired.  Otherwise, we disable the channel checkboxes, as they don't make sense for a mono sound.
*/

- soundDidChange
{
	[super soundDidChange];
	
	if ([[moduleController currentSound] channelCount] > 1)
	{
		[applyToLeftButton setEnabled:YES];
		[applyToRightButton setEnabled:YES];
		[applyToAllButton setEnabled:YES];
	}
	else
	{
		[applyToLeftButton setEnabled:NO];
		[applyToRightButton setEnabled:NO];
		[applyToAllButton setEnabled:NO];
	}
	
	if ([moduleController currentWindow])
	{
		[applyButton setEnabled:YES];
	}
	else
	{
		[applyButton setEnabled:NO];
	}
	
	return self;
}


/*
- showEnvelopePanel:sender

When we receive this message, we display the enveloping control panel.  We check to see if the control panel exists, and if not, we load it from the nib file.  We find the bundle our class is in, and ask it for the path to our nib file.  We then load the nib.  If any of this process fails, we show an alert panel explaining the failure, and we return nil, indicating that we failed to display our control panel; otherwise we tell the control panel that it should only become key if it needs to, and we tell it to float above other windows.

If we succeed in loading the control panel, or if it already existed, we set the channel checkboxes to selected so that any enveloping action works on all channels by default.  We then send ourself a soundDidChange message so that we will update the enveloping control panel based on the current sound.  Finally, we order our control panel to the front.
*/

- showEnvelopePanel:sender
{
	if (!envelopePanel)
	{
		if (![ResoundNibs loadNibNamed: @"EnvelopePanel" owner:self])
		{
			NSRunAlertPanel (nil, @"Unable to locate EnvelopePanel.nib", nil, nil, nil);
			return nil;
		}
		
		if (!envelopePanel)
		{
			NSRunAlertPanel (nil, @"Unable to locate envelope panel", nil, nil, nil);
			return nil;
		}
	}
	
	[applyToLeftButton setState:1];
	[applyToRightButton setState:1];
	[applyToAllButton setState:1];
	[self soundDidChange];
	
	[envelopePanel orderFront:self];	
	
	return self;
}


/*
- applyEnvelope:sender

We are sent this message when the user presses the Apply button on the enveloping control panel.  We determine the current sound and the associated sound view, determine the data format of the sound and the number of channels in the sound, and set up pointers to the sound data so that we can access it as different types, based on the sound data format.  We then determine what the current sound selection is.  If there is no sound or no selection in the sound, we give an error message and return nil to indicate that we didn't apply the envelope.  We also check the format of the sound data - we only support 8-bit MuLaw, 8-bit Linear, 16-bit Linear, Float, and Double.  If the sound data is in any other format, we give an error message and return nil.  And we make sure that at least one channel is selected to which the envelope is to be applied - if no channels are selected, we give an error message and return nil.

Next, we make sure that the current sound is not playing by sending moduleController a stop message.  (moduleController is inherited from our Module superclass.)  We use SNDSwapSoundToHost to make sure that the sound data is in an appropriate format to work with, based on our host hardware architecture.  We then save the sound window's title and change it to inform the user that we are applying the envelope - we force the window to update because otherwise the title doesn't update until after we've finished applying the envelope.

Our envelope is very simple - in fact, it's simply a fade from silence to full sound, or the reverse.  We determine a changeFactor - the amount by which the sound level of each sample should differ from the previous sample.  We ask the inOutMatrix whether the user wants to fade in or out.  And we determine the channels to which the effect is to be applied.

Now we step through each sample of the sound selection.  We determine a multiplier based on the current sample and whether we're fading in or out - this multiplier is between 0.0 and 1.0, so that we get a certain percentage of the sound.  Each sample has a data element for each channel, so we get each channel's data element and multiply it by out multiplier value to get the modified value.  Depending on the sound data format, we address the data differently - as 8-bit, 16-bit, float, and double values as appropriate.  For MuLaw data, we have to convert the data element to a linear value, apply our multiplier, and convert the data element back to MuLaw.

Finally, we use SNDSwapHostToSound to convert the sound data back to an architecture independant data format, and then tell the module controller that we have changed our sound.  This causes the sound window to be marked as modified.  We reset the sound window's original title.
*/

- applyEnvelope:sender
{
	Sound *		current  = [moduleController currentSound];
	SoundView *	cview  = [moduleController currentSoundView];
	int		dataFormat;
	int		channelCount;
	int		channel;
	int		sampleCount;
	short *		data16;
	char *		data8;
	float *		dataFloat;
	double *	dataDouble;
	short		temp16;
	int		index;
	int		firstSample;
	int		sample;
	int		sampleLength;
	double		changeFactor;
	double		sampleMultiplier;
	BOOL		fadeIn;
	BOOL		applyToChannel[MAX_CHANNELS];
	
	[current compactSamples];
	
	dataFormat = [current dataFormat];
	channelCount = [current channelCount];
	sampleCount = [current sampleCount];
	data16 = (short *)[current data];
	data8 = (char *)data16;
	dataFloat = (float *)data16;
	dataDouble = (double *)data16;
	
	[cview getSelection:&firstSample size:&sampleLength];
		
	if ((current == nil) || !sampleLength)		// no sound
	{
		NSRunAlertPanel (@"No Sound", @"There is no sound or selection on which to perform this operation.", nil, nil, nil);
		return nil;
	}
	
	switch (dataFormat)
	{
		case SND_FORMAT_MULAW_8:
		case SND_FORMAT_LINEAR_8:
		case SND_FORMAT_LINEAR_16:
		case SND_FORMAT_FLOAT:
		case SND_FORMAT_DOUBLE:
			break;
		default:
			NSRunAlertPanel (@"Wrong Sound Format", @"Enveloping is not supported for this sound format.", nil, nil, nil);
			return nil;
			break;
	}
	
	if (![applyToLeftButton state] && ![applyToRightButton state] && ![applyToAllButton state])
	{
		NSRunAlertPanel (@"No Channels Selected", @"At least one channel must be selected.", nil, nil, nil);
		
		return nil;
	}
	
	if (sampleLength > (LOTS_OF_SAMPLES * channelCount))
	{
		if (![moduleController runLongTimePanel])
		{
			return nil;
		}
	}
	
	[moduleController stop];
        [[moduleController currentSoundView] checkForCurrentDataOnPasteboard];		
	SNDSwapSoundToHost ((void *)data16, (void *)data16, sampleCount, channelCount, dataFormat);
	
	changeFactor = 1.0 / (double) sampleLength;
	
	fadeIn = [[inOutMatrix selectedCell] tag] == 0;
	applyToChannel[0] = ([applyToLeftButton state] != 0) || ([applyToAllButton state] != 0);
	applyToChannel[1] = ([applyToRightButton state] != 0) || ([applyToAllButton state] != 0);
	
	for (sample = firstSample; sample < (firstSample + sampleLength); sample++)
	{
		index = sample * channelCount;
		
		if (fadeIn)
		{
			sampleMultiplier = (sample - firstSample) * changeFactor;
		}
		else	// fade out
		{
			sampleMultiplier = 1.0 - ((sample - firstSample) * changeFactor);
		}
		
		for (channel = 0; channel < channelCount; channel++)
		{
			if (applyToChannel[channel])
			{
				switch (dataFormat)
				{
				case SND_FORMAT_LINEAR_8:
					data8[index + channel] = data8[index + channel] * sampleMultiplier;
					break;
				case SND_FORMAT_MULAW_8:
					temp16  = SNDiMulaw (data8[index + channel]);
					temp16 = temp16 * sampleMultiplier;
					data8[index + channel] = SNDMulaw (temp16);
					break;
				case SND_FORMAT_LINEAR_16:
					data16[index + channel] = data16[index + channel] * sampleMultiplier;
					break;
				case SND_FORMAT_FLOAT:
					dataFloat[index + channel] = dataFloat[index + channel] * sampleMultiplier;
					break;
				case SND_FORMAT_DOUBLE:
					dataDouble[index + channel] = dataDouble[index + channel] * sampleMultiplier;
					break;
				}
			}
		}
	}
	
	SNDSwapHostToSound ((void *)data16, (void *)data16, sampleCount, channelCount, dataFormat);
	[moduleController soundChanged];
	
	return self;
}


@end	// EnvelopeModule
