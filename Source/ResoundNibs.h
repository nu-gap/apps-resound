/* ResoundNibs.h
 *
 * Platform-aware NIB loading for Resound.
 *
 * The 1998-era OpenStep/Rhapsody .nib files cannot be loaded by the GNUstep
 * runtime, so every .nib in this tree has a converted .gorm partner
 * (produced with gormtool, gnustep/apps-gorm branch OPENSTEP_nib_support)
 * that the runtime GSGormLoader can read.  The original .nib folders stay
 * in place as the migration source; they will stepwise be re-saved as
 * modern NIBs, at which point both platforms load the same name again.
 *
 * Call sites therefore pass the LOGICAL nib name (no extension):
 *
 *     [ResoundNibs loadNibNamed:@"Console" owner:self];
 *
 * The helper resolves that to the physical resource per platform:
 *   - GNUstep : "Console"   (the GSModelLoaderFactory tries every
 *                   supported type and finds Console.gorm)
 *   - native  : "Console.nib" (the 1998 file, original behaviour)
 *
 * When a particular nib is migrated to a modern re-saved NIB, only the
 * resolution in ResoundNibs.m changes - not the call sites.
 *
 * Part of the Resound GNUstep port; see docs/RESOUND_SNDKIT_PLAN.md
 * (NIB migration section).
 */

#import <Foundation/Foundation.h>

@interface ResoundNibs : NSObject

/* Load the nib with the given logical name (without extension).
   Identical semantics to [NSBundle loadNibNamed:owner:]. */
+ (BOOL) loadNibNamed: (NSString *)name
		 owner: (id)owner;

/* The physical resource name (with extension where needed) for the
   logical nib name on this platform.  The single place where the
   per-platform resolution - and any future re-nib ladder - lives. */
+ (NSString *) nibResourceNamed: (NSString *)name;

@end
