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

This file derives from the Sound (ResoundSound) category that used
to live in FileController.{h,m}; it was extracted into its own file
as part of the SndKit migration (see docs/RESOUND_SNDKIT_PLAN.md,
Phase 1) so that the file-I/O core can be built and tested without
the rest of the document controller.
*/

#import <Foundation/Foundation.h>
#import <SndKit/SndKit.h>

@interface Snd (ResoundSound)

/*
  Loads a sound from a "foreign" sound file, i.e. any format the
  SndKit (libsndfile) readers understand (.wav, .au, .aiff, .snd,
  .pcm, .ogg, .flac, ...).

  The Jerome Genest legacy readers that used to be consulted here for
  some of these formats (AuReader, WavReader, ...) were dropped with
  the SndKit migration (licensing); SndKit sniffs the file content,
  so a single initFromSoundfile: now covers all of them.

  If convert is YES, the sound is additionally normalised to
  Resound's historical "safe" format - 16-bit linear, SND_RATE_LOW,
  stereo - which is the behaviour of the convertOnOpen preference
  (the SND_RATE_* constants come from SndKit's SndStruct.h).

  Returns the receiver, fully loaded, on success; returns nil if the
  file cannot be read.  This is a deliberate divergence from the
  Rhapsody behaviour, which returned an empty sound for unreadable
  files: callers must check for nil.
*/
- (Snd *) initFromForeignSoundFile: (NSString *) filename
                           convert: (BOOL) convert;

/*
  Saves the sound to the sound file fn.

  sv is an object exposing the sound's info string via -info
  (returning an NSString); in production this is the sound view.
  The Rhapsody version stored the info in the view because of a
  SoundKit info-string bug and spliced it into a throwaway
  SNDSoundStruct before writing; under SndKit the info string is a
  first-class NSString on the Snd, so it is simply assigned.  sv may
  be nil.

  If backup is YES and the file exists, the existing file is renamed
  to the same name plus a ".~snd" extension first (Resound's backup
  extension).

  Returns the receiver on success; nil on failure (the error is
  reported on stderr).
*/
- (Snd *) saveToSoundFile: (NSString *) fn
                      sv: (id) sv
                  backup: (BOOL) backup;

@end
