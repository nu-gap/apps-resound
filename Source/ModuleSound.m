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

  ModuleSound.[h|m]
  Sean Luke
  
  ModuleSound is a category defining methods that module makers have
  available to them when manipulating sounds.  The big stuff here is FFT
  simplification.  
  
  ****************************************************************************/



#import "ModuleSound.h"
#import <SndKit/SndKit.h>
#import "fft.h"

@implementation Snd(ModuleSound)


/*** sampleSize
  Returns the size of a full sample (including all channels).
  */

- (int) sampleSize { return [self sampleSizePerChannel]*[self channelCount]; }



/*** sampleSizePerChannel
  Returns the size of a sample for each channel.
 */

- (int) sampleSizePerChannel
    {
    int format=[self dataFormat];
    switch(format)
	{
      case SND_FORMAT_MULAW_8: case SND_FORMAT_LINEAR_8: 
	return 1; break;
      case SND_FORMAT_LINEAR_16 : return 2; break;
      case SND_FORMAT_LINEAR_24: return 3; break;
      case SND_FORMAT_LINEAR_32: return 4; break;
      case SND_FORMAT_FLOAT: return sizeof(float); break;
      case SND_FORMAT_DOUBLE: return sizeof(double); break;
      default: return 0; break;
	}
    }


/*** nextPositivePowerOfTwo:
  Returns the smallest positive power of two greater than or equal to value..
 */

+ (int) nextPositivePowerOfTwo:(int)value
    {
    int y; int t;
    if (value<=1) return 1;
    y=value;
    for(t=0;value=value>>1;t++);
    if (1<<t==y) return y;
    else return 1<<(t+1);
    }



/* data should already be n Hz, floating-point sound. fft_length must be of the power of 2 above or equal to sample_length.  This is computed as
   fft_length=[Sound nextPositivePowerOfTwo:sample_length].  You should strive for sample_length==fft_length (that is, sample_length is a power of 2) except when it's definitely not possible. 
   
   fft will be an array of fft_length number-pairs.  This means that fft should be of size fft_length*2.
   */


/*** performFFTFromSoundData:::::toFFTData::
  Returns an FFT on the given selection of the sound data.  Follow the instructions above.
 */

+ (int) performFFTFromSoundData:(char*)data:(int)start_sample:
(int)sample_length:(int)dataFormat:(int)numChannels
 toFFTData:(float*)fft_data:(int)fft_length
    {
    int x;
    float j;

    if (numChannels!=1) return 0;

    switch(dataFormat)
	{
      case SND_FORMAT_MULAW_8: 
	for(x=0;x<sample_length;x++)
	  {
	  fft_data[x*2]=((float)(SndMuLawToLinear(data[x+start_sample])))/SHRT_MAX;
	  fft_data[x*2+1]=0;
	  } break;
      case SND_FORMAT_LINEAR_8: for(x=0;x<sample_length;x++)
	  {
	  fft_data[x*2]=((float)(data[x+start_sample]))/CHAR_MAX;
	  fft_data[x*2+1]=0;
	  } break;
      case SND_FORMAT_LINEAR_16: for(x=0;x<sample_length;x++)
	  {
	  fft_data[x*2]=((float)(((signed short*)data)[x+start_sample]))/SHRT_MAX;
	  fft_data[x*2+1]=0;
	  } break;
      case SND_FORMAT_FLOAT:	for(x=0;x<sample_length;x++)
	  {
	  fft_data[x*2]=(float)(((float*)data)[x+start_sample]);
	  fft_data[x*2+1]=0;
	  } break;
      case SND_FORMAT_DOUBLE:	for(x=0;x<sample_length;x++)
	  {
	  fft_data[x*2]=(float)(((double*)data)[x+start_sample]);
	  fft_data[x*2+1]=0;
	  } break;
      default: return 0; break;
	}
    
    
    for(x=sample_length*2;x<fft_length*2;x++)
	{
	fft_data[x]=0; fft_data[x+1]=0;
	}
    fft(fft_data,fft_length,FORWARD_FFT);
    
    /* Lastly, multiply by 2/fft_length.  I'm not sure why this is. */
    
    j=2.0/((float)fft_length);
    for(x=0;x<fft_length*2;x+=2) fft_data[x]*=j;
    return 1;
    }






/*** performIFFTFromSoundData:::::fromFFTData::
  Returns an IFFT on the given selection of the sound data.  Follow the instructions above
  the previous method.
 */

+ (int) performIFFTToSoundData:(char*)data:(int)start_sample:
(int)sample_length:(int)dataFormat:(int)numChannels
 fromFFTData:(float*)fft_data:(int)fft_length
    {
    int x;
    float j;
    
    if (numChannels!=1) return 0;
    if (dataFormat!=SND_FORMAT_MULAW_8 && 
	dataFormat!=SND_FORMAT_LINEAR_8 &&
	dataFormat!=SND_FORMAT_LINEAR_16 &&
	dataFormat!=SND_FORMAT_FLOAT &&
	dataFormat!=SND_FORMAT_DOUBLE) return 0;
    
    /* Lastly, multiply by fft_length/2.  I'm not sure why this is. */

    j=((float)fft_length)/2.0;
    for(x=0;x<fft_length*2;x+=2) fft_data[x]*=j;
    fft(fft_data,fft_length,INVERSE_FFT);

    for(x=0;x<sample_length;x++)
	data[x+start_sample]=fft_data[x*2];

    switch(dataFormat)
	{
      case SND_FORMAT_MULAW_8: 
	for(x=0;x<sample_length;x++)
	    {
	    data[x+start_sample]=SndLinearToMuLaw((signed short)(fft_data[x*2]*SHRT_MAX));
	    } 
	break;
      case SND_FORMAT_LINEAR_8: for(x=0;x<sample_length;x++)
	  {
	  data[x+start_sample]=(char)(fft_data[x*2]*CHAR_MAX);
	  } break;
      case SND_FORMAT_LINEAR_16: for(x=0;x<sample_length;x++)
	  {
	  data[x+start_sample]=(signed short)(fft_data[x*2]*SHRT_MAX);
	  } break;
      case SND_FORMAT_FLOAT:	for(x=0;x<sample_length;x++)
	  {
	  data[x+start_sample]=fft_data[x*2];
	  } break;
      case SND_FORMAT_DOUBLE:	for(x=0;x<sample_length;x++)
	  {
	  data[x+start_sample]=(double)(fft_data[x*2]);
	  } break;
      default: return 0; break;   /* Shouldn't ever happen */
	}
    return 1;
    }



@end
