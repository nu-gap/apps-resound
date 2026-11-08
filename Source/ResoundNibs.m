/* ResoundNibs.m
 *
 * Platform-aware NIB loading for Resound - see ResoundNibs.h.
 *
 * The GNUstep define is supplied by gnustep-config --objc-flags on the
 * GNUstep toolchain and is absent from native Apple builds, which is
 * exactly the split the ladder needs:
 *
 *   1998 .nib (native loads it)  --+
 *                                  +--  the same logical name at every
 *   converted .gorm (GNUstep)  ---+     call site
 *
 * The 1998 folder and the .gorm folder sit side by side in the tree
 * (Resources/Console.nib + Resources/Console.gorm); the Makefile picks
 * which one the bundle carries per platform.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "ResoundNibs.h"

@implementation ResoundNibs

+ (BOOL) loadNibNamed: (NSString *)name
		 owner: (id)owner
{
	return [NSBundle loadNibNamed: [self nibResourceNamed: name]
	   owner: owner];
}

+ (NSString *) nibResourceNamed: (NSString *)name
{
#ifdef GNUSTEP
	/* GNUstep cannot read the 1998 typed-stream .nib; the converted
	   .gorm (same logical name) does.  Passing the name without an
	   extension makes the GSModelLoaderFactory try every supported
	   type, which is also what will happen when a future modern
	   re-nib under the same name replaces the .gorm. */
	return name;
#else
	/* Native (OPENSTEP / Mac OS / Rhapsody / Cocoa): the 1998 .nib
	   loads as-is - the original 1998 behaviour, .nib extension
	   explicit. */
	return [name stringByAppendingPathExtension: @"nib"];
#endif
}

@end
