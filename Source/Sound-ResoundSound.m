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
to live in FileController.m; it was extracted and migrated to SndKit
as part of the SndKit port (see docs/RESOUND_SNDKIT_PLAN.md,
Phase 1).  The intended behaviour is pinned by the contract tests in
test/resoundio.m.
****************************************************************************

  Resound's file I/O for Snd objects (SndKit).

  Loading from foreign files: any format SndKit (libsndfile) can
  read.  One thing this category offers is auto-conversion to a
  "safe" sound format on request; the Rhapsody code's rationale
  (a SoundKit bug that played 11 kHz files at twice their speed)
  no longer applies under SndKit, but the user-visible behaviour of
  the convertOnOpen preference - normalising to a small 16-bit
  stereo sound - is preserved.

  Saving: saving to a sound file with auto-backup (in the form of
  ".~snd" extensions).  The Rhapsody implementation had to work
  around a SoundKit bug (info strings were reset to 4 bytes long
  whenever an SNDSoundStruct was modified) by storing the info
  string in the sound view and splicing it into a throwaway
  SNDSoundStruct whose dataLocation was pointed, via an
  SND_FORMAT_INDIRECT hack, at the real sound's struct.  SndKit has
  no such bug - the info string is a first-class NSString - so the
  whole hack is gone.
****************************************************************************/

#import <Foundation/Foundation.h>
#import <SndKit/SndKit.h>
#import "Sound-ResoundSound.h"
#import <string.h>
#import <unistd.h>

@implementation Snd (ResoundSound)


/**** initFromForeignSoundFile::
  Loads a sound from a foreign sound file.  If convert is true, the
  sound is normalised to Resound's "safe" format afterwards.

  Foreign extensions historically included:

  .snd    (Resound's sound format)
  .~snd   (Resound's backup sound extension)
  .au     (Sun au files, very similar to snd)
  .aiff   (Mac AIFF files)
  .wav    (WAV files)
  .voc    (VOC files)
  .mp2    (MPEG files)

  Under SndKit the per-format legacy readers (and the .mp2/.mp1
  paths in particular, which needed the proprietary MpegReader) are
  gone: libsndfile reads whatever it reads and sniffs the content,
  so the extension only decides whether the optional normalisation
  conversion applies.  (Files whose content is not a readable sound
  file - including most old .mp2 files, since libsndfile knows no
  MPEG - simply fail to load and nil is returned.)  */

- (Snd *) initFromForeignSoundFile: (NSString *) filename
                           convert: (BOOL) convert
    {
    if (filename == nil || [filename length] == 0)
        return nil;

    NSString *extension = [filename pathExtension];
    BOOL native =
        ([extension caseInsensitiveCompare: @"snd"] == NSOrderedSame ||
         [extension caseInsensitiveCompare: @"~snd"] == NSOrderedSame);

    if (!native && ![Snd isPathForSoundFile: filename])
        NSLog(@"Foreign File Error: '%@' has an unrecognised extension; "
              "attempting to read it anyway", filename);

    Snd *snd = [self initFromSoundfile: filename];
    if (snd == nil)
        {
        NSLog(@"Resound: cannot read sound file '%@' (not a readable "
              "sound file)", filename);
        return nil;
        }

    if (!native && convert)
        {
        /*
         * The Rhapsody code's rationale (a SoundKit bug that played
         * 11 kHz files at twice their speed) no longer applies under
         * SndKit; the user-visible promise - normalise to a small
         * "safe" format when the convertOnOpen preference is set -
         * is preserved.
         */
        int err = [snd convertToSampleFormat: SND_FORMAT_LINEAR_16
                               samplingRate: SND_RATE_LOW
                               channelCount: 2];
        if (err != SND_ERR_NONE)
            {
            /*
             * The sound itself loaded fine; keep it in its original
             * format rather than discarding it.
             */
            NSLog(@"Resound: conversion of '%@' failed: %@; keeping the "
                  "original format", filename, SndSoundError(err));
            }
        }

    return snd;
    }



/**** saveToSoundFile:::
  Saves the sound to a sound file, possibly backing up an existing
  file first (in the form of a ".~snd" extension).

  The Rhapsody implementation created a throwaway Sound whose
  SNDSoundStruct was listed as not compacted, pointed (via
  SND_FORMAT_INDIRECT) at the real sound's struct, and carried the
  info string loaded from the sound view - a workaround for a
  SoundKit info-string bug.  Under SndKit the info string is a
  first-class NSString on the Snd, the writer compacts on demand,
  and no such workaround exists or is needed.  */

- (Snd *) saveToSoundFile: (NSString *) fn
                      sv: (id) sv
                  backup: (BOOL) backup    // Returns NULL if unsuccessful
    {
    if (fn == nil || [fn length] == 0)
        {
        NSLog(@"Resound ERROR:  no filename to save file");
        return NULL;
        }

    int err;

    /* LOAD INFO STRING */
    if ([sv info] != nil)
        [self setInfo: [sv info]];

    /* Compact first.  NeXT's writeSoundfile was broken with respect
       to this; the SndKit writer compacts on demand, but a compact
       sound is what the format guard below expects. */
    [self compactSamples];

    /*
     * SndKit's file writer only knows how to emit FLOAT, LINEAR_16
     * and LINEAR_32 data; any other in-memory format would be
     * written out as an empty file while reporting success.
     * Normalise to 16-bit first.
     */
    switch ([self dataFormat])
        {
        case SND_FORMAT_FLOAT:
        case SND_FORMAT_LINEAR_16:
        case SND_FORMAT_LINEAR_32:
            break;
        default:
            [self convertToSampleFormat: SND_FORMAT_LINEAR_16];
        }

    if (backup &&
        access([fn fileSystemRepresentation], 0) == 0)   /* file exists */
        {
        /* Change the extension to ".~snd" (Resound's backup extension) */
        NSString *backupName =
            [[fn stringByDeletingPathExtension]
                stringByAppendingString: @".~snd"];
        if (rename([fn fileSystemRepresentation],
                   [backupName fileSystemRepresentation]) != 0)
            NSLog(@"Resound: warning: could not back up '%@' to '%@'",
                  fn, backupName);
        }

    err = [self writeSoundfile: fn];
    if (err != SND_ERR_NONE)
        {
        /*
         * SndSoundError returns an NSString under SndKit
         * (Rhapsody's SNDSoundError returned a char*).
         */
        NSString *msg = SndSoundError(err);
        fprintf(stderr, "Resound ERROR:  cannot save file because:  %s\n",
                msg != nil ? [msg UTF8String] : "unknown error");
        return NULL;
        }

    return self;
    }

@end
