/*
 * SndKit smoke test: exercises the libsndfile-backed file I/O path
 * (load .wav -> write .au -> reload) without any audio device, so it
 * is safe in a headless CI.
 *
 * Usage: sndsmoke input.wav output.au
 */
#import <Foundation/Foundation.h>
#import <SndKit/SndKit.h>
#import <stdio.h>

int main(int argc, const char **argv)
{
  @autoreleasepool {
    if (argc < 3) {
      fprintf(stderr, "usage: %s input.wav output.au\n", argv[0]);
      return 2;
    }

    printf("SndKit %s file I/O smoke test\n",
           @"".UTF8String);

    NSArray *exts = [Snd soundFileExtensions];
    printf("supported sound file extensions: %s\n",
           [[exts componentsJoinedByString:@" "] UTF8String]);

    NSString *in = [NSString stringWithUTF8String:argv[1]];
    NSString *out = [NSString stringWithUTF8String:argv[2]];

    if (![Snd isPathForSoundFile:in]) {
      fprintf(stderr, "FAIL: %s is not a recognized sound file path\n", argv[1]);
      return 1;
    }

    Snd *snd = [[Snd alloc] initFromSoundfile:in];
    if (snd == nil) {
      fprintf(stderr, "FAIL: initFromSoundfile %s returned nil\n", argv[1]);
      return 1;
    }

    printf("loaded:  sampleCount=%ld  rate=%.2f  channels=%ld  format=%ld  dataSize=%ld\n",
           (long)[snd lengthInSampleFrames],
           [snd samplingRate],
           (long)[snd channelCount],
           (long)[snd dataFormat],
           (long)[snd dataSize]);

    int err = [snd writeSoundfile:out];
    if (err != SND_ERR_NONE) {
      NSString *msg = SndSoundError(err);
      fprintf(stderr, "FAIL: writeSoundfile %s -> %s\n", argv[2],
              msg ? msg.UTF8String : "unknown error");
      return 1;
    }
    printf("wrote:   %s (ok)\n", argv[2]);

    // round trip: read the file we just wrote
    Snd *rt = [[Snd alloc] initFromSoundfile:out];
    if (rt == nil) {
      fprintf(stderr, "FAIL: round-trip initFromSoundfile %s returned nil\n", argv[2]);
      return 1;
    }
    printf("reload:  sampleCount=%ld  rate=%.2f  channels=%ld  format=%ld\n",
           (long)[rt lengthInSampleFrames],
           [rt samplingRate],
           (long)[rt channelCount],
           (long)[rt dataFormat]);

    if ([rt lengthInSampleFrames] != [snd lengthInSampleFrames]) {
      fprintf(stderr, "FAIL: round-trip sample count mismatch\n");
      return 1;
    }

    printf("PASS\n");
    return 0;
  }
}
