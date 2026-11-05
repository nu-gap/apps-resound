/*
 * resoundio - contract test for Resound's file I/O on SndKit.
 *
 * Pins the intended behaviour of the Sound (ResoundSound) category
 * (Source/Sound-ResoundSound.{h,m}) - the test-driven Phase 1 of the
 * GNUstep / SndKit port (docs/RESOUND_SNDKIT_PLAN.md).
 *
 * The Rhapsody original cannot be run (its SoundKit is unavailable),
 * so these tests define the new API contract against real audio
 * files; the migration is the work that makes them pass.
 *
 * Usage: resoundio input.wav workdir
 *
 * Headless: no audio device, no display.  Exit code 0 = all pass.
 */

#import <Foundation/Foundation.h>
#import <SndKit/SndKit.h>
#import "Sound-ResoundSound.h"
#import <math.h>
#import <stdio.h>
#import <string.h>
#import <sys/stat.h>
#import <unistd.h>

static int nChecks = 0;
static int nFailures = 0;

static void check(BOOL cond, const char *what)
{
    nChecks++;
    if (cond) {
        printf("ok   %s\n", what);
    } else {
        nFailures++;
        printf("FAIL %s\n", what);
    }
}

static void checkNear(double a, double b, double tol, const char *what)
{
    check(fabs(a - b) <= tol, what);
}

static NSString *P(NSString *dir, NSString *name)
{
    return [dir stringByAppendingPathComponent: name];
}

/* A stand-in for the sound view's copy of the info string.  The
 * production object is the ResoundMiscSoundView (Phase 2); the
 * category only needs something that responds to -info returning
 * an NSString. */
@interface InfoHolder : NSObject
{
    NSString *infoString;
}
- initWithInfo:(NSString *)info;
- (NSString *)info;
@end

@implementation InfoHolder
- initWithInfo:(NSString *)info
{
    if ((self = [super init]))
        infoString = [info copy];
    return self;
}
- (NSString *)info
{
    return infoString;
}
@end

int main(int argc, const char **argv)
{
    @autoreleasepool {
    if (argc < 3) {
        fprintf(stderr, "usage: %s input.wav workdir\n", argv[0]);
        return 2;
    }

    NSString *input = [NSString stringWithUTF8String: argv[1]];
    NSString *dir   = [NSString stringWithUTF8String: argv[2]];
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm createDirectoryAtPath: dir withIntermediateDirectories: YES
                           attributes: nil error: nil]) {
        fprintf(stderr, "FAIL: cannot create workdir %s\n", argv[2]);
        return 1;
    }

    printf("resound file I/O contract test (workdir: %s)\n", argv[2]);

    /* ---------- reference: the source file, via raw SndKit ---------- */

    Snd *ref = [[Snd alloc] initFromSoundfile: input];
    if (ref == nil) {
        fprintf(stderr, "FAIL: cannot read reference file %s\n", argv[1]);
        return 1;
    }
    unsigned long refFrames = [ref lengthInSampleFrames];
    double        refRate   = [ref samplingRate];
    int           refChans  = [ref channelCount];
    if (refFrames == 0) {
        fprintf(stderr, "FAIL: reference file has no samples\n");
        return 1;
    }
    printf("reference: frames=%lu  rate=%.1f  channels=%d\n",
           refFrames, refRate, refChans);

    /* ---------- fixtures, generated with raw SndKit ---------- */

    Snd *fx;

    [fm copyItemAtPath: input toPath: P(dir, @"tone.wav") error: nil];
    check([fm fileExistsAtPath: P(dir, @"tone.wav")],
          "fixture: tone.wav (copy of the input)");

    fx = [[Snd alloc] initFromSoundfile: input];
    check([fx writeSoundfile: P(dir, @"tone.au")] == SND_ERR_NONE,
          "fixture: tone.au written");
    fx = [[Snd alloc] initFromSoundfile: input];
    check([fx writeSoundfile: P(dir, @"tone.aiff")] == SND_ERR_NONE,
          "fixture: tone.aiff written");
    fx = [[Snd alloc] initFromSoundfile: input];
    check([fx writeSoundfile: P(dir, @"tone.snd")] == SND_ERR_NONE,
          "fixture: tone.snd written");
    fx = [[Snd alloc] initFromSoundfile: input];
    [fx convertToSampleFormat: SND_FORMAT_LINEAR_16];
    check([fx writeSoundfile: P(dir, @"tone16.wav")] == SND_ERR_NONE,
          "fixture: tone16.wav written");

    [@"this is not a sound file\n" writeToFile: P(dir, @"corrupt.wav")
                                      atomically: NO
                                        encoding: NSUTF8StringEncoding
                                           error: nil];
    [@"some notes\n" writeToFile: P(dir, @"notes.txt")
                     atomically: NO
                       encoding: NSUTF8StringEncoding
                          error: nil];
    /* wav bytes under the legacy .voc name: the reader must sniff the
     * content, not trust the extension */
    [fm copyItemAtPath: input toPath: P(dir, @"fake.voc") error: nil];
    [fm copyItemAtPath: input toPath: P(dir, @"TONE.WAV") error: nil];

    /* ===== A. initFromForeignSoundFile:convert: ===== */

    Snd *s;

    s = [[Snd alloc] initFromForeignSoundFile: P(dir, @"tone.wav") convert: NO];
    check(s != nil, "A1  load .wav: returns a sound");
    if (s != nil) {
        check([s lengthInSampleFrames] == refFrames,
              "A2  .wav: frame count preserved");
        checkNear([s samplingRate], refRate, 0.5,
                  "A3  .wav: sampling rate preserved");
        check([s channelCount] == refChans,
              "A4  .wav: channel count preserved");
        check([s dataFormat] == SND_FORMAT_FLOAT,
              "A5  .wav: decoded to float (libsndfile always decodes to float)");
    }

    s = [[Snd alloc] initFromForeignSoundFile: P(dir, @"tone.au") convert: NO];
    check(s != nil && [s lengthInSampleFrames] == refFrames &&
          fabs([s samplingRate] - refRate) < 0.5 && [s channelCount] == refChans,
          "A6  load .au: parameters preserved");

    s = [[Snd alloc] initFromForeignSoundFile: P(dir, @"tone.aiff") convert: NO];
    check(s != nil && [s lengthInSampleFrames] == refFrames &&
          fabs([s samplingRate] - refRate) < 0.5 && [s channelCount] == refChans,
          "A7  load .aiff: parameters preserved");

    s = [[Snd alloc] initFromForeignSoundFile: P(dir, @"tone.snd") convert: NO];
    check(s != nil && [s lengthInSampleFrames] == refFrames &&
          fabs([s samplingRate] - refRate) < 0.5 && [s channelCount] == refChans,
          "A8  load .snd (Resound's document format): parameters preserved");

    s = [[Snd alloc] initFromForeignSoundFile: P(dir, @"TONE.WAV") convert: NO];
    check(s != nil, "A9  uppercase extension accepted");

    s = [[Snd alloc] initFromForeignSoundFile: P(dir, @"fake.voc") convert: NO];
    check(s != nil && [s lengthInSampleFrames] == refFrames,
          "A10 legacy .voc name: content sniffed, extension irrelevant");

    s = [[Snd alloc] initFromForeignSoundFile: P(dir, @"tone.wav") convert: YES];
    check(s != nil, "A11 load .wav with convert=YES: returns a sound");
    if (s != nil) {
        check([s dataFormat] == SND_FORMAT_LINEAR_16,
              "A12 convert: normalised to 16-bit linear");
        checkNear([s samplingRate], (double)SND_RATE_LOW, 0.5,
                  "A13 convert: normalised to SND_RATE_LOW");
        check([s channelCount] == 2,
              "A14 convert: normalised to stereo");
        /*
         * Resampling to half the rate halves the frame count; what the
         * conversion preserves is the length in seconds.
         */
        check(fabs([s lengthInSampleFrames] -
                   refFrames * ((double)SND_RATE_LOW / refRate)) <= 2.0,
              "A15 convert: length preserved (resampler edge rounding)");
        check(fabs([s duration] - [ref duration]) <= 0.05,
              "A16 convert: duration preserved");
    }

    check([[Snd alloc] initFromForeignSoundFile: P(dir, @"corrupt.wav")
                             convert: NO] == nil,
          "A17 corrupt file: returns nil (deliberate divergence: the Rhapsody "
          "code returned an empty sound)");
    check([[Snd alloc] initFromForeignSoundFile: P(dir, @"missing.wav")
                             convert: NO] == nil,
          "A18 missing file: returns nil");
    check([[Snd alloc] initFromForeignSoundFile: P(dir, @"notes.txt")
                             convert: NO] == nil,
          "A19 unknown extension: returns nil");
    check([[Snd alloc] initFromForeignSoundFile: nil convert: NO] == nil,
          "A20 nil filename: returns nil");

    /* ===== B. saveToSoundFile:sv:backup: ===== */

    /* .aiff is the round-trip container on purpose: libsndfile
     * persists the info comment (AIFF ICOMM) for aiff/wav/snd/ogg,
     * but not for .au. */
    NSString *rt = P(dir, @"roundtrip.aiff");

    s = [[Snd alloc] initFromForeignSoundFile: P(dir, @"tone.wav") convert: NO];
    check(s != nil, "B0  load for save tests");

    if (s != nil) {
        InfoHolder *sv = [[InfoHolder alloc] initWithInfo: @"Resound contract test"];
        Snd *ret = [s saveToSoundFile: rt sv: sv backup: NO];
        check(ret == s, "B1  save returns self on success");
        check([fm fileExistsAtPath: rt], "B2  save created the file");

        Snd *rt2 = [[Snd alloc] initFromSoundfile: rt];
        check(rt2 != nil && [rt2 lengthInSampleFrames] == refFrames &&
              fabs([rt2 samplingRate] - refRate) < 0.5 &&
              [rt2 channelCount] == refChans,
              "B3  reload after save: parameters preserved (.aiff)");
        check([rt2 info] != nil &&
              [[rt2 info] isEqualToString: @"Resound contract test"],
              "B4  info string round-trips into the file (the old "
              "SNDSoundStruct hack is gone)");

        sv = [[InfoHolder alloc] initWithInfo: @"second revision"];
        [s saveToSoundFile: rt sv: sv backup: YES];
        check([fm fileExistsAtPath: P(dir, @"roundtrip.~snd")],
              "B5  backup=YES: existing file renamed to .~snd");

        rt2 = [[Snd alloc] initFromSoundfile: P(dir, @"roundtrip.~snd")];
        check(rt2 != nil &&
              [[rt2 info] isEqualToString: @"Resound contract test"],
              "B6  backup preserved the previous content");
        rt2 = [[Snd alloc] initFromSoundfile: rt];
        check(rt2 != nil &&
              [[rt2 info] isEqualToString: @"second revision"],
              "B7  new content written in place");

        [s saveToSoundFile: rt sv: sv backup: NO];
        {
            int backups = 0;
            for (NSString *name in [fm contentsOfDirectoryAtPath: dir
                                                          error: nil])
                if ([name hasSuffix: @".~snd"])
                    backups++;
            check(backups == 1, "B8  backup=NO: no additional .~snd files");
        }

        ret = [s saveToSoundFile: P(dir, @"roundtrip2.au") sv: nil backup: NO];
        check(ret == s && [fm fileExistsAtPath: P(dir, @"roundtrip2.au")],
              "B9  save with a nil sv succeeds");

        /* The SndKit writer only emits float / 16-bit / 32-bit data;
         * anything else would be written as an empty file while
         * reporting success.  The category must normalise first. */
        [s convertToSampleFormat: SND_FORMAT_LINEAR_8];
        check([s dataFormat] == SND_FORMAT_LINEAR_8,
              "B10 sound converted to 8-bit in memory");
        ret = [s saveToSoundFile: P(dir, @"guard8.wav") sv: nil backup: NO];
        check(ret == s, "B11 saving an 8-bit sound succeeds");
        rt2 = [[Snd alloc] initFromSoundfile: P(dir, @"guard8.wav")];
        check(rt2 != nil && [rt2 lengthInSampleFrames] == refFrames,
              "B12 the 8-bit save is not an empty file (writer-format guard)");

        ret = [s saveToSoundFile: [[dir stringByAppendingPathComponent: @"no-such-dir"]
                                   stringByAppendingPathComponent: @"x.au"]
                         sv: nil backup: NO];
        check(ret == nil, "B13 save into a missing directory fails cleanly");
        check([s saveToSoundFile: nil sv: nil backup: NO] == nil,
              "B14 save with a nil filename fails cleanly");
    }

    s = [[Snd alloc] initFromForeignSoundFile: P(dir, @"tone.wav") convert: NO];
    Snd *ret = [s saveToSoundFile: P(dir, @"c.aiff") sv: nil backup: NO];
    Snd *rt2 = [[Snd alloc] initFromSoundfile: P(dir, @"c.aiff")];
    check(ret == s, "B15 save into a different container returns self");
    check(rt2 != nil && [rt2 lengthInSampleFrames] == refFrames &&
          fabs([rt2 samplingRate] - refRate) < 0.5 && [rt2 channelCount] == refChans,
          "B16 save into a different container (.aiff) round-trips");

    s = [[Snd alloc] initFromForeignSoundFile: P(dir, @"tone.wav") convert: NO];
    ret = [s saveToSoundFile: P(dir, @"doc.snd") sv: nil backup: NO];
    rt2 = [[Snd alloc] initFromSoundfile: P(dir, @"doc.snd")];
    check(ret == s, "B17 native .snd save returns self");
    check(rt2 != nil && [rt2 lengthInSampleFrames] == refFrames &&
          fabs([rt2 samplingRate] - refRate) < 0.5 && [rt2 channelCount] == refChans,
          "B18 native .snd document round-trips");

    /* ---------- summary ---------- */

    printf("%d checks, %d failures\n", nChecks, nFailures);
    if (nFailures == 0) {
        printf("PASS\n");
        return 0;
    }
    return 1;
    }
}
