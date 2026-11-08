/*
 * resoundnib - format and load tests for the converted NIB assets.
 *
 * The 1998-era .nib files cannot be read by the GNUstep runtime, so
 * every .nib in the tree has a converted .gorm twin (gormtool,
 * gnustep/apps-gorm branch OPENSTEP_nib_support); the 1998 folder
 * stays in place as the source of the stepwise re-nib migration
 * (docs/RESOUND_SNDKIT_PLAN.md, NIB migration section).  The app
 * loads the logical name via Source/ResoundNibs.{h,m}, which the
 * GNUstep build resolves to the .gorm twin.
 *
 * Modes:
 *   resoundnib --check [root ...]      headless; the CI gate.
 *       For every .gorm folder under the roots (skipping third_party,
 *       .git, obj and Resound.app): objects.gorm carries the GNUstep
 *       archive magic and data.classes parses as a property list.
 *       A fresh built bundle is covered by adding Resound.app/Resources.
 *
 *   resoundnib --load [root ...]       needs a display; local only.
 *       Loads every .gorm for real, one child process each, through
 *       the same NSBundle nib machinery the app uses.  The 1998 nibs
 *       reference app classes that are still blocked, so the
 *       expectation is self-adapting: the child resolves every class
 *       named in data.classes; if all are known, the load must
 *       succeed, and the graceful "missing class" failure is what is
 *       expected until the owning unit lands.  A crash is always a
 *       failure.  The ported console classes are compiled in, so the
 *       console must load here.
 *
 *   resoundnib --load-one <gorm-dir>   internal; the child process.
 *
 * Exit code 0 = all pass.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "ResoundNibs.h"

#import <stdio.h>
#import <string.h>
#import <unistd.h>
#import <sys/stat.h>
#import <sys/wait.h>

/* ------------------------------------------------------------------ */
/* Finding the .gorm folders                                          */

static NSSet *skipNames = nil;

static void initSkipNames(void)
{
    if (skipNames == nil)
        skipNames = [NSSet setWithObjects:
                     @"third_party", @".git", @"obj", @"Resound.app", nil];
}

/* Recursively collect the .gorm folders below root (absolute). */
static void findGorms(NSString *dir, NSMutableSet *found)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath: dir isDirectory: &isDir] || !isDir)
        return;

    BOOL isGorm = [[dir pathExtension] isEqualToString: @"gorm"];
    if (isGorm)
        {
        [found addObject: dir];
        return;                       /* never descend into a gorm folder */
        }

    NSArray *contents = [fm contentsOfDirectoryAtPath: dir error: nil];
    NSEnumerator *en = [contents objectEnumerator];
    NSString *name = nil;
    while ((name = [en nextObject]) != nil)
        {
        if ([skipNames containsObject: name])
            continue;
        findGorms([dir stringByAppendingPathComponent: name], found);
        }
}

static NSArray *collectGorms(NSString *root)
{
    initSkipNames();
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *abs = [root isAbsolutePath] ? root :
        [[fm currentDirectoryPath] stringByAppendingPathComponent: root];
    abs = [abs stringByStandardizingPath];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath: abs isDirectory: &isDir] || !isDir)
        {
        fprintf(stderr, "FAIL: root '%s' is not a directory\n",
                [root fileSystemRepresentation]);
        return nil;
        }
    NSMutableSet *set = [NSMutableSet set];
    findGorms(abs, set);
    NSMutableArray *sorted = [[NSMutableArray alloc] initWithArray: [set allObjects]];
    [sorted sortUsingSelector: @selector(compare:)];
    return sorted;
}

/* ------------------------------------------------------------------ */
/* --check: the asset format gate (headless)                          */

static const char *kGormMagic = "GNUstep archive";

static int checkGorm(NSString *gormDir, const char *rel)
{
    NSString *objs = [gormDir stringByAppendingPathComponent: @"objects.gorm"];
    NSString *cls  = [gormDir stringByAppendingPathComponent: @"data.classes"];

    NSData *objData = [NSData dataWithContentsOfFile: objs];
    if (objData == nil || [objData length] == 0)
        {
        printf("FAIL %s: objects.gorm missing or empty\n", rel);
        return 1;
        }
    if ([objData length] < strlen(kGormMagic) ||
        memcmp([objData bytes], kGormMagic, strlen(kGormMagic)) != 0)
        {
        printf("FAIL %s: objects.gorm is not a GNUstep archive "
               "(bad magic)\n", rel);
        return 1;
        }

    NSData *clsData = [NSData dataWithContentsOfFile: cls];
    if (clsData == nil)
        {
        printf("FAIL %s: data.classes missing\n", rel);
        return 1;
        }
    NSError *err = nil;
    id plist = [NSPropertyListSerialization propertyListWithData: clsData
                                                     options: 0
                                                      format: nil
                                                        error: &err];
    if (plist == nil)
        {
        printf("FAIL %s: data.classes does not parse (%s)\n", rel,
               [[err localizedDescription] UTF8String]);
        return 1;
        }

    printf("ok   %s (%lu bytes, %lu class descriptions)\n", rel,
           (unsigned long) [objData length],
           ([plist isKindOfClass: [NSDictionary class]]) ?
           [(NSDictionary *) plist count] : 1UL);
    return 0;
}

static int runCheck(NSArray *roots)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *cwd = [fm currentDirectoryPath];
    int failures = 0, total = 0;
    NSMutableSet *seen = [NSMutableSet set];

    NSEnumerator *ren = [roots objectEnumerator];
    NSString *root = nil;
    while ((root = [ren nextObject]) != nil)
        {
        NSArray *gorms = collectGorms(root);
        if (gorms == nil)
            { failures++; continue; }
        NSEnumerator *gen = [gorms objectEnumerator];
        NSString *g = nil;
        while ((g = [gen nextObject]) != nil)
            {
            if ([seen containsObject: g])
                continue;
            [seen addObject: g];
            total++;
            NSString *rel = [g hasPrefix: [NSString stringWithFormat: @"%@/", cwd]] ?
                [g substringFromIndex: [cwd length] + 1] : g;
            if (checkGorm(g, [rel fileSystemRepresentation]))
                failures++;
            }
        }

    printf("== resoundnib --check: %d gorm folders, %d failures ==\n",
           total, failures);
    return (failures == 0 && total > 0) ? 0 : 1;
}

/* ------------------------------------------------------------------ */
/* --load-one: one gorm, one process                                  */

/* A nib "owner" that swallows every outlet connection instead of
 * throwing on unknown keys: the 1998 nibs wire outlets at the owner
 * that the ported class does not (yet) have, and the load must not
 * die on that. */
@interface ProbeOwner : NSObject
{
@public
    NSMutableDictionary *store;
}
@end

@implementation ProbeOwner
- (id) init
{
    self = [super init];
    if (self != nil)
        store = [[NSMutableDictionary alloc] init];
    return self;
}
- (void) dealloc
{
    [store release];
    [super dealloc];
}
- (void) setValue: (id)value forUndefinedKey: (NSString *)key
{
    [store setObject: (value != nil ? value : [NSNull null]) forKey: key];
}
- (id) valueForKey: (NSString *)key
{
    return [store objectForKey: key];
}
@end

/* Every class named in the gorm's data.classes, resolvable? */
static int classesResolvable(NSString *gormDir)
{
    NSString *cls = [gormDir stringByAppendingPathComponent: @"data.classes"];
    NSData *data = [NSData dataWithContentsOfFile: cls];
    if (data == nil)
        return 0;
    id plist = [NSPropertyListSerialization propertyListWithData: data
                                                     options: 0
                                                      format: nil
                                                        error: nil];
    if (![plist isKindOfClass: [NSDictionary class]])
        return 0;
    NSDictionary *dict = (NSDictionary *) plist;
    NSEnumerator *en = [dict keyEnumerator];
    NSString *name = nil;
    while ((name = [en nextObject]) != nil)
        {
        if ([name hasPrefix: @"##"])
            continue;              /* comment entry, not a class */
        if (NSClassFromString(name) == Nil)
            return 0;
        }
    return 1;
}

static int runLoadOne(NSString *gormDir)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    /* A gorm folder is a model inside its parent directory; loading
     * goes through the same NSBundle primitive the app's
     * [ResoundNibs loadNibNamed:owner:] reduces to (NSBundle's
     * class-level +loadNibNamed: searches the main bundle, which a
     * test tool is not). */
    NSBundle *bundle = [NSBundle bundleWithPath: [gormDir stringByDeletingLastPathComponent]];
    NSString *stem = [[[gormDir lastPathComponent]
                       stringByDeletingPathExtension] retain];
    NSString *name = [ResoundNibs nibResourceNamed: stem];
    [stem release];

    unsigned long before = [[NSApp windows] count];
    ProbeOwner *owner = [[ProbeOwner alloc] init];
    NSDictionary *table = [NSDictionary dictionaryWithObject: owner
                                                     forKey: NSNibOwner];
    int loaded = 0;
    NS_DURING
        loaded = [bundle loadNibFile: name
                  externalNameTable: table
                           withZone: [owner zone]];
    NS_HANDLER
        printf("CAUGHT %s: %s\n",
               [[localException name] UTF8String],
               [[localException reason] UTF8String]);
    NS_ENDHANDLER

    unsigned long after = [[NSApp windows] count];
    int classesOk = classesResolvable(gormDir);
    printf("RNI name=%s loaded=%d windows=%lu classes_ok=%d\n",
           [stem UTF8String], loaded, after - before, classesOk);
    /* The expectation: if every class the archive names is resolvable
     * in this process, the load must have succeeded; otherwise the
     * graceful missing-class failure is what is due until the owning
     * unit lands.  A crash is reported the same way (non-zero exit). */
    [pool release];
    return (!loaded && classesOk) ? 1 : 0;
}

/* ------------------------------------------------------------------ */
/* --load: the parent, one child per gorm                             */

static int runLoad(NSArray *roots)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *selfPath = nil;
    {
        char buf[4096];
        ssize_t n = readlink("/proc/self/exe", buf, sizeof buf - 1);
        if (n > 0)
            {
                buf[n] = '\0';
                selfPath = [[NSString stringWithUTF8String: buf]
                            stringByStandardizingPath];
            }
        if (selfPath == nil)
            selfPath = [[[[NSProcessInfo processInfo] arguments]
                          objectAtIndex: 0] stringByStandardizingPath];
    }

    NSString *cwd = [fm currentDirectoryPath];
    int total = 0, failures = 0, loadedCount = 0;
    NSMutableSet *seen = [NSMutableSet set];

    NSEnumerator *ren = [roots objectEnumerator];
    NSString *root = nil;
    while ((root = [ren nextObject]) != nil)
        {
        NSArray *gorms = collectGorms(root);
        if (gorms == nil)
            { failures++; continue; }
        NSEnumerator *gen = [gorms objectEnumerator];
        NSString *g = nil;
        while ((g = [gen nextObject]) != nil)
            {
            if ([seen containsObject: g])
                continue;
            [seen addObject: g];
            total++;
            NSString *rel = [g hasPrefix: [NSString stringWithFormat: @"%@/", cwd]] ?
                [g substringFromIndex: [cwd length] + 1] : g;

            pid_t pid = fork();
            if (pid < 0)
                {
                    fprintf(stderr, "FAIL %s: fork failed\n",
                            [rel UTF8String]);
                    failures++;
                    continue;
                }
            if (pid == 0)
                {
                    /* child */
                    char *c0 = (char *) [selfPath fileSystemRepresentation];
                    char *cm = (char *) [@"--load-one" fileSystemRepresentation];
                    char *cg = (char *) [g fileSystemRepresentation];
                    execv(c0, (char *[]) { c0, cm, cg, NULL });
                    _exit(127);
                }

            int status = 0;
            waitpid(pid, &status, 0);
            if (WIFSIGNALED(status))
                {
                    printf("FAIL %s: loader crashed (signal %d)\n",
                           [rel UTF8String], WTERMSIG(status));
                    failures++;
                    continue;
                }
            if (!WIFEXITED(status) || WEXITSTATUS(status) != 0)
                {
                /* Child exit discipline: 0 = the load succeeded, or
                 * the failure is the expected missing-class one (its
                 * classes are not all ported yet).  Non-zero = crash,
                 * or the classes are all resolvable yet the load
                 * still failed. */
                printf("FAIL %s: load failed although its classes "
                       "are resolvable (exit %d)\n", [rel UTF8String],
                       WIFEXITED(status) ? WEXITSTATUS(status) : -1);
                failures++;
                continue;
                }
            printf("ok   %s\n", [rel UTF8String]);
            loadedCount++;
            }
        }

    printf("== resoundnib --load: %d gorm folders, %d failures ==\n",
           total, failures);
    return (failures == 0 && total > 0) ? 0 : 1;
}

/* ------------------------------------------------------------------ */

int main(int argc, const char *argv[])
{
    @autoreleasepool
        {
        int mode = 0;             /* 0 = check, 1 = load, 2 = load-one */
        NSMutableArray *roots = [NSMutableArray array];

        if (argc < 2)
            {
                fprintf(stderr,
                        "usage: resoundnib --check [root ...] | "
                        "--load [root ...] | --load-one <gorm-dir>\n");
                return 2;
            }
        NSString *modeArg = [NSString stringWithUTF8String: argv[1]];
        if ([@"--check" isEqualToString: modeArg])
            mode = 0;
        else if ([@"--load" isEqualToString: modeArg])
            mode = 1;
        else if ([@"--load-one" isEqualToString: modeArg])
            mode = 2;
        else
            {
                fprintf(stderr, "unknown mode '%s'\n", argv[1]);
                return 2;
            }
        for (int i = 2; i < argc; i++)
            [roots addObject: [NSString stringWithUTF8String: argv[i]]];
        if ([roots count] == 0)
            [roots addObject: @"."];

        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        int rc;
        if (mode == 0)
            rc = runCheck(roots);
        else if (mode == 1)
            rc = runLoad(roots);
        else
            {
                /* --load-one needs a display and a real AppKit app */
                NSApp = [[NSApplication alloc] init];
                if (NSApp == nil)
                    {
                        fprintf(stderr,
                                "cannot start NSApplication "
                                "(display available?)\n");
                        rc = 3;
                    }
                else
                    rc = runLoadOne(roots[0]);
            }
        [pool release];
        return rc;
        }
}
