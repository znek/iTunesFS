/*
  Copyright (c) 2007, Marcus Müller <znek@mulle-kybernetik.com>.
  All rights reserved.


  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

  - Redistributions of source code must retain the above copyright notice, this
    list of conditions and the following disclaimer.

  - Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

  - Neither the name of Mulle kybernetiK nor the names of its contributors
    may be used to endorse or promote products derived from this software
    without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
  POSSIBILITY OF SUCH DAMAGE.
*/

#import "common.h"
#import "iTunesFileSystem.h"
#import "iTunesLibrary.h"
#import "iPodLibrary.h"
#import "NSArray+Extensions.h"
#import "NSObject+Extensions.h"

@interface iTunesFileSystem (Private)
- (void)addLibrary:(iTunesLibrary *)_lib;
- (void)removeLibrary:(iTunesLibrary *)_lib;
- (void)didMountRemovableDevice:(NSNotification *)_notif;
- (void)didUnmountRemovableDevice:(NSNotification *)_notif;

- (BOOL)showLibraries;

- (NSArray *)pathFromFSPath:(NSString *)_path;
- (id)lookupPath:(NSString *)_path;
@end

@implementation iTunesFileSystem

static BOOL     doDebug     = NO;
static BOOL     debugLookup = NO;
static BOOL     ignoreIPods = NO;
static NSString *fsIconPath = nil;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  NSBundle       *mb;
  
  if (didInit) return;
  didInit     = YES;
  ud          = [NSUserDefaults standardUserDefaults];
  doDebug     = [ud boolForKey:@"iTunesFileSystemDebugEnabled"];
  debugLookup = [ud boolForKey:@"iTunesFSDebugPathLookup"];
  ignoreIPods = [ud boolForKey:@"NoIPods"];
  mb          = [NSBundle mainBundle];
#ifndef GNU_GUI_LIBRARY
  fsIconPath  = [[mb pathForResource:@"iTunesFS" ofType:@"icns"] copy];
  NSAssert(fsIconPath != nil, @"Couldn't find iTunesFS.icns!");
#endif
}

#ifdef GNU_GUI_LIBRARY
+ (id)sharedApplication {
  return NSApp;
}
#endif

/* notifications */

- (void)fuseWillMount {
  iTunesLibrary *lib;

  self->libMap = [[NSMutableDictionary alloc] initWithCapacity:3];
  self->volMap = [[NSMutableDictionary alloc] initWithCapacity:3];

  // add default library
  lib = [[iTunesLibrary alloc] init];
  [self addLibrary:lib];
  [lib release];

  if (!ignoreIPods) {
    NSArray              *volPaths;
    unsigned             i, count;
    NSNotificationCenter *nc;

    // add mounted iPods
    volPaths = [[NSWorkspace sharedWorkspace] mountedRemovableMedia];
    count    = [volPaths count];
    for (i = 0; i < count; i++) {
      NSString *path;
      
      path = [volPaths objectAtIndex:i];
      if ([iPodLibrary isIPodAtMountPoint:path]) {
        lib = [[iPodLibrary alloc] initWithMountPoint:path];
        [self addLibrary:lib];
        [lib release];
      }
    }
    
    // mount/unmount registration
    nc = [[NSWorkspace sharedWorkspace] notificationCenter];
    [nc addObserver:self
        selector:@selector(didMountRemovableDevice:)
        name:NSWorkspaceDidMountNotification
        object:nil];
    [nc addObserver:self
        selector:@selector(willUnmountRemovableDevice:)
        name:NSWorkspaceWillUnmountNotification
        object:nil];
    [nc addObserver:self
        selector:@selector(didUnmountRemovableDevice:)
        name:NSWorkspaceDidUnmountNotification
        object:nil];
  }
}

- (void)fuseDidUnmount {
  NSNotificationCenter *nc;

  nc = [[NSWorkspace sharedWorkspace] notificationCenter];
  [nc removeObserver:self];

  [self->libMap release];
  [self->volMap release];
}

- (void)didMountRemovableDevice:(NSNotification *)_notif {
  NSString *path;

  path = [[_notif userInfo] objectForKey:@"NSDevicePath"];
  if ([iPodLibrary isIPodAtMountPoint:path]) {
    iTunesLibrary *lib;
    BOOL          prevShowLibraries;

    prevShowLibraries = [self showLibraries];
    if (doDebug) NSLog(@"Will add library for iPod at path: %@", path);
    lib = [[iPodLibrary alloc] initWithMountPoint:path];
    [self addLibrary:lib];
    [lib release];

    if ([self showLibraries] != prevShowLibraries) {
      if (doDebug)
        NSLog(@"posting -noteFileSystemChanged: for %@", [self mountPoint]);
      [[NSWorkspace sharedWorkspace] noteFileSystemChanged:[self mountPoint]];
    }
  }
}

- (void)willUnmountRemovableDevice:(NSNotification *)_notif {
  NSString      *path;
  iTunesLibrary *lib;
  
  path = [[_notif userInfo] objectForKey:@"NSDevicePath"];
  lib  = [self->volMap objectForKey:path];
  if (lib) {
    if (doDebug)
      NSLog(@"Will close library for unmounting iPod at path: %@", path);
    [lib close];
  }
}

- (void)didUnmountRemovableDevice:(NSNotification *)_notif {
  NSString      *path;
  iTunesLibrary *lib;

  path = [[_notif userInfo] objectForKey:@"NSDevicePath"];
  lib  = [self->volMap objectForKey:path];
  if (lib) {
    BOOL prevShowLibraries;

    if (doDebug)
      NSLog(@"Will remove library for unmounted iPod at path: %@", path);
    [self removeLibrary:lib];

    if ([self showLibraries] != prevShowLibraries) {
      if (doDebug)
        NSLog(@"posting -noteFileSystemChanged: for %@", [self mountPoint]);
      [[NSWorkspace sharedWorkspace] noteFileSystemChanged:[self mountPoint]];
    }
  }
}

/* adding/removing libraries */

- (void)addLibrary:(iTunesLibrary *)_lib {
  NSString *path;

  path = [_lib mountPoint];
  if (path)
    [self->volMap setObject:_lib forKey:path];
  [self->libMap setObject:_lib forKey:[_lib name]];
}

- (void)removeLibrary:(iTunesLibrary *)_lib {
  NSString *path;

  path = [_lib mountPoint];
  if (path)
    [self->volMap removeObjectForKey:path];
  [self->libMap removeObjectForKey:[_lib name]];
}

/* private */

- (BOOL)showLibraries {
  if (ignoreIPods) return NO;
  if ([self->libMap count] == 1) return NO;
  return YES;
}

- (NSArray *)pathFromFSPath:(NSString *)_path {
  NSArray *path;

  path = [_path pathComponents];
  if (![self showLibraries]) {
    NSMutableArray *fakePath;
    
    /* We're not showing the library list by faking the only existing
     * library into the path - the lookup will then be done as usual.
     */
    fakePath = [path mutableCopy];
    [fakePath insertObject:[[self->libMap allKeys] lastObject] atIndex:1];
    path = [fakePath autorelease];
  }
  return path;
}

- (id)lookupPath:(NSString *)_path {
  NSArray  *path;
  id       obj;
  unsigned i, count;

  path = [self pathFromFSPath:_path];
  count = [path count];
  if (!count) return nil;
  obj = [self lookupPathComponent:[path objectAtIndex:0]];
  if (debugLookup)
    NSLog(@"lookup [#0, %@] -> %@", [path objectAtIndex:0], obj);
  for (i = 1; i < count; i++) {
    obj = [obj lookupPathComponent:[path objectAtIndex:i]];
    if (debugLookup)
      NSLog(@"lookup [#%d, %@] -> %@", i, [path objectAtIndex:i], obj);
  }
  return obj;
}

/* iTunesFS lookup */

- (id)lookupPathComponent:(NSString *)_pc {
  if ([_pc isEqualToString:@"/"]) return self;
  // TODO: add fake Spotlight entries
  return [self->libMap lookupPathComponent:_pc];
}

- (NSArray *)directoryContents {
  // TODO: fake Spotlight database
  return [self->libMap directoryContents];
}

- (NSDictionary *)fileSystemAttributes {
  NSMutableDictionary *attrs;
  
  attrs = [[NSMutableDictionary alloc] initWithCapacity:2];
  //    [attrs setObject:defaultSize forKey:NSFileSystemSize];
  [attrs setObject:[NSNumber numberWithInt:0] forKey:NSFileSystemFreeSize];
  return [attrs autorelease];
}

- (BOOL)isDirectory {
  return YES;
}

/* required stuff */

/* currently we have this scheme:
 * Libraries / Playlists / Tracks
 */
- (NSArray *)directoryContentsAtPath:(NSString *)_path {
  return [[self lookupPath:_path] directoryContents];
}

- (BOOL)fileExistsAtPath:(NSString *)_path isDirectory:(BOOL *)isDirectory {
  id obj;
  
  obj          = [self lookupPath:_path];
  *isDirectory = [obj isDirectory];
  if ([obj isDirectory]) return YES;
  return [obj isFile];
}

- (NSDictionary *)fileAttributesAtPath:(NSString *)_path {
  return [[self lookupPath:_path] fileAttributes];
}

- (NSData *)contentsAtPath:(NSString *)_path {
  return [[self lookupPath:_path] fileContents];
}

- (NSString *)pathContentOfSymbolicLinkAtPath:(NSString *)_path {
  return [[self lookupPath:_path] symbolicLinkTarget];
}

/* optional */

- (BOOL)shouldMountInFinder {
  return YES;
}

- (BOOL)usesResourceForks {
  return YES;
}

- (NSString *)iconFileForPath:(NSString *)_path {
  if ([_path isEqualToString:@"/"]) return fsIconPath;
  return nil;
}

- (NSImage *)iconForPath:(NSString *)_path {
  return [[self lookupPath:_path] icon];
}

- (NSDictionary *)fileSystemAttributesAtPath:(NSString *)_path {
  return [[self lookupPath:_path] fileSystemAttributes];
}

/* debugging */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [[NSMutableString alloc] initWithCapacity:60];
  [ms appendString:@"<"];
  [ms appendFormat:@"%@ 0x%x", NSStringFromClass(self->isa), self];
  [ms appendString:@": #libs:"];
  [ms appendFormat:@"%d", [self->libMap count]];
  if (!ignoreIPods) {
    [ms appendString:@" #iPods:"];
    [ms appendFormat:@"%d", [self->volMap count]];
  }
  [ms appendString:@">"];
  return [ms autorelease];
}

@end
