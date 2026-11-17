/*
resoundmenu
For the GNUstep port of Resound (gnustep-port branch)

A CI gate (non-fatal, like the launch check) and local diagnostic:
loads the app's main model the way NSApplicationMain does
(loadNibFile with the app in the external name table as the nib
owner), dumps the main menu and the delegate's model outlets, then
posts NSApplicationDidFinishLaunching so the app's real launch path
runs - including ModuleController loadModules, which loads the
installed *.rmod modules and builds their menu trees - and dumps the
menu again.  Point it at the built app bundle (argv[1]); the module
itself must be installed (make install in its module directory) for
the load to find it.  The --direct flag calls the delegate's method
instead of posting the notification (delivery vs. load-path split).

Usage: resoundmenu <path-to-Resound.app> [--direct]
Runs under a display (the main model creates windows).
*/

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <stdlib.h>

#import "ResoundNibs.h"
#import "ModuleController.h"

static void dumpIvars (id obj)
{
    /* Report which of FileController's model outlets the nib loader
       actually connected - the suspects for the 1998 NSNibConnector
       (an empty establishConnection stub in current GNUstep). */
    static const char *names[] = {
        "mainMenu", "moduleController", "consoleManager",
        "soundManager", "editController", "inspectorManager"
    };
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList ([obj class], &count);
    unsigned int i;
    int j;
    for (j = 0; j < 6; j++)
    {
        int found = 0;
        for (i = 0; i < count; i++)
        {
            if (strcmp (ivar_getName (ivars[i]), names[j]) == 0)
            {
                id val = object_getIvar (obj, ivars[i]);
                printf ("  outlet %-18s = %s\n",
                        names[j], val ? "set" : "nil");
                found = 1;
                break;
            }
        }
        if (!found)
            printf ("  outlet %-18s = (ivar not in class)\n", names[j]);
    }
    free (ivars);
}

static void dumpMenu (NSMenu *menu, int depth)
{
    if (menu == nil)
    {
        return;
    }
    int i;
    int n = [menu numberOfItems];
    for (i = 0; i < n; i++)
    {
        NSMenuItem *item = [menu itemAtIndex: i];
        NSMenu *sub = [item submenu];
        printf ("%*s- [%s] %s%s\n",
                depth * 2, "",
                [item isEnabled] ? "on" : "off",
                [[item title] UTF8String],
                sub ? " >" : "");
        if (sub)
            dumpMenu (sub, depth + 1);
    }
}

static NSMenuItem *itemTitled (NSMenu *menu, NSString *title)
{
    int i;
    int n = [menu numberOfItems];
    for (i = 0; i < n; i++)
        if ([[menu itemAtIndex: i] title] != nil &&
            [[[menu itemAtIndex: i] title] isEqualToString: title])
            return [menu itemAtIndex: i];
    return nil;
}

int main (int argc, char **argv)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSApplication *app = [NSApplication sharedApplication];

    /* The app loads its main model from its own bundle
       (Resources/Resound.gorm).  A test tool's main bundle is the
       test directory, so point the same NSBundle primitive at the
       app bundle (argv[1], defaulting to ".." from test/, which
       resolves to the repo root - fine for local runs). */
    setvbuf (stdout, NULL, _IOLBF, 0);      /* the dumps must survive a crash */
    NSString *root = argc > 1
        ? [NSString stringWithUTF8String: argv[1]] : @"..";
    if (![root isAbsolutePath])
        root = [[[NSFileManager defaultManager] currentDirectoryPath]
            stringByAppendingPathComponent: root];
    NSBundle *bundle = [NSBundle bundleWithPath: root];
    /* The app's NSApplicationMain loads its main model the OpenStep
       way: loadNibFile on the app bundle with the app in the
       external name table as "File's Owner" (NSNibOwner).  Do the
       same thing, pointed at the app bundle.  (Sub-nibs go through
       +[NSBundle loadNibNamed:], which resolves against *this
       tool's* main bundle - the test directory - so they fail
       silently here; the load path under test is the main model
       plus the module load, and that runs for real.) */
    NSDictionary *table = [NSDictionary dictionaryWithObject: app
                                                     forKey: NSNibOwner];
    printf ("== loading the main model from %s ==\n", [root UTF8String]);
    int loaded = 0;
    @try
        { loaded = [bundle loadNibFile: @"Resound"
                     externalNameTable: table
                              withZone: [app zone]]; }
    @catch (NSException *e)
        {
        printf ("loadNibFile threw: %s\n", [[e name] UTF8String]);
        printf ("  reason: %s\n", [[e reason] UTF8String]);
        }
    printf ("loadNibFile Resound: %s\n", loaded ? "ok" : "FAILED");
    if (!loaded)
        return 1;

    @try
        {
        id delegate = [app delegate];
        printf ("NSApp delegate: %s\n",
                delegate ? [[[delegate class] description] UTF8String]
                : "(nil)");
        if (delegate)
        {
            printf ("delegate outlets after model load:\n");
            dumpIvars (delegate);
        }
        NSMenu *mainMenu = [app mainMenu];
        printf ("NSApp mainMenu has %lu items, NSApp windows: %lu\n",
                (unsigned long)[mainMenu numberOfItems],
                (unsigned long)[[app windows] count]);

        NSArray *libPaths =
            NSSearchPathForDirectoriesInDomains (NSLibraryDirectory,
                                                 NSAllDomainsMask, TRUE);
        printf ("library paths (NSLibraryDirectory, existing only):\n");
        NSEnumerator *lpEnum = [libPaths objectEnumerator];
        NSString *lp = nil;
        NSFileManager *fm = [NSFileManager defaultManager];
        while ((lp = [lpEnum nextObject]) != nil)
        {
            BOOL isDir = NO;
            NSString *r = [lp stringByAppendingPathComponent: @"Resound"];
            printf ("  %-50s Resound exists=%d\n",
                    [lp UTF8String],
                    [fm fileExistsAtPath: r isDirectory: &isDir] ? 1 : 0);
        }
        printf ("main bundle: %s\n",
                [[[NSBundle mainBundle] bundlePath] UTF8String]);
        fflush (stdout);

        printf ("== main menu, BEFORE launch (model state) ==\n");
        dumpMenu (mainMenu, 0);

        if (argc > 2 && strcmp (argv[2], "--direct") == 0)
        {
            /* Bypass the notification and call the delegate's method
               directly: this tests the load path itself (search dirs,
               bundle, menu wiring) independent of delivery. */
            printf ("\n== calling delegate applicationDidFinishLaunching: directly ==\n");
            if ([[app delegate] respondsToSelector:
                        @selector(applicationDidFinishLaunching:)])
                [[app delegate] applicationDidFinishLaunching: nil];
            else
                printf ("delegate does not respond!\n");
            fflush (stdout);
        }
        else
        {
            printf ("\n== posting NSApplicationDidFinishLaunching ==\n");
            [[NSNotificationCenter defaultCenter]
                postNotificationName: NSApplicationDidFinishLaunchingNotification
                              object: app];
        }

        id delegateAfter = [app delegate];
        printf ("NSApp delegate after launch: %s, windows: %lu\n",
                delegateAfter ? [[[delegateAfter class] description] UTF8String]
                : "(nil)",
                (unsigned long)[[app windows] count]);
        NSEnumerator *wEnum = [[app windows] objectEnumerator];
        NSWindow *w = nil;
        while ((w = [wEnum nextObject]) != nil)
        {
            NSString *t = [w title];
            printf ("  window: '%s' visible=%d\n",
                    t ? [t UTF8String] : "(no title)",
                    [w isVisible] ? 1 : 0);
        }

        printf ("\n== main menu, AFTER launch (modules loaded) ==\n");
        dumpMenu (mainMenu, 0);

        NSMenuItem *modules = itemTitled (mainMenu, @"Modules");
        if (modules)
            printf ("\nModules item: enabled=%d, submenu items=%lu\n",
                    [modules isEnabled],
                    (unsigned long)[[modules submenu] numberOfItems]);
        else
            printf ("\nmain menu has no 'Modules' item\n");
        NSMenuItem *appMenu = [mainMenu itemAtIndex: 0];
        if (appMenu)
        {
            NSMenuItem *moduleInfo =
                itemTitled ([appMenu submenu], @"Module Info");
            if (moduleInfo)
                printf ("app menu 'Module Info' submenu items=%lu\n",
                        (unsigned long)[[moduleInfo submenu] numberOfItems]);
            else
                printf ("app menu has no 'Module Info' item\n");
        }
        fflush (stdout);
        }
    @catch (NSException *e)
        {
        printf ("PROBE EXCEPTION after load: %s\n  reason: %s\n",
                [[e name] UTF8String], [[e reason] UTF8String]);
        fflush (stdout);
        }

    [pool drain];
    return 0;
}
