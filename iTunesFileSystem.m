/*
  Copyright (c) 2007-2010, Marcus Müller <znek@mulle-kybernetik.com>.
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
#import "JBiPodLibrary.h"
#import "IPhoneDiskIPodLibrary.h"
#import "NSObject+FUSEOFS.h"

@interface iTunesFileSystem (Private)
- (void)addLibrary:(iTunesLibrary *)_lib;
- (void)removeLibrary:(iTunesLibrary *)_lib;
- (void)didMountRemovableDevice:(NSNotification *)_notif;
- (void)didUnmountRemovableDevice:(NSNotification *)_notif;

- (BOOL)showLibraries;

- (NSArray *)pathFromFSPath:(NSString *)_path;
- (id)lookupPath:(NSString *)_path;

- (BOOL)needsLocalOption;
- (BOOL)wantsAllowOtherOption;

@end

@implementation iTunesFileSystem

static BOOL     doDebug          = NO;
static BOOL     ignoreITunes     = NO;
static BOOL     ignoreIPods      = NO;
static BOOL     allowOtherOption = NO;
static NSString *fsIconPath      = nil;
static NSArray  *fakeVolumePaths = nil;
static NSString *iPhoneDiskPath  = @"/Volumes/iPhoneDisk";

+ (void)initialize {
  static BOOL didInit = NO;

  if (didInit) return;

  NSUserDefaults *ud;
  NSBundle       *mb;

  didInit          = YES;
  ud               = [NSUserDefaults standardUserDefaults];
  doDebug          = [ud boolForKey:@"iTunesFileSystemDebugEnabled"];
  ignoreITunes     = [ud boolForKey:@"NoITunes"];
  ignoreIPods      = [ud boolForKey:@"NoIPods"];
  allowOtherOption = [ud boolForKey:@"FUSEOptionAllowOther"];

  if (ignoreITunes && ignoreIPods)
    NSLog(@"ERROR: ignoring iTunes and iPods doesn't make sense at all.");
  fakeVolumePaths = [[ud arrayForKey:@"iPodMountPoints"] copy];
  mb              = [NSBundle mainBundle];
#ifndef GNU_GUI_LIBRARY
  fsIconPath      = [[mb pathForResource:@"iTunesFS" ofType:@"icns"] copy];
  NSAssert(fsIconPath != nil, @"Couldn't find iTunesFS.icns!");
#endif
}

/* NSObject(GMUserFileSystemLifecycle) */

- (void)willMount {
  iTunesLibrary *lib;

  if (doDebug)
    NSLog(@"iTunesFileSystem will mount now");

  self->libMap = [[NSMutableDictionary alloc] initWithCapacity:3];
  self->volMap = [[NSMutableDictionary alloc] initWithCapacity:3];

  // add default library
  if (!ignoreITunes) {
    lib = [[iTunesLibrary alloc] init];
    [self addLibrary:lib];
    [lib release];
  }
  if (!ignoreIPods) {
    // add mounted iPods
    NSArray *volPaths = [[NSWorkspace sharedWorkspace] mountedRemovableMedia];

    if (fakeVolumePaths)
      volPaths = [volPaths arrayByAddingObjectsFromArray:fakeVolumePaths];

    // workaround for Finder's inability to treat FUSE filesystems as
    // removable media
    if (![volPaths containsObject:iPhoneDiskPath]) {
      volPaths = [volPaths arrayByAddingObject:iPhoneDiskPath];
    }

    lib = nil;
    unsigned count = [volPaths count];
    for (unsigned i = 0; i < count; i++) {
      NSString *path = [volPaths objectAtIndex:i];
      if (doDebug)
        NSLog(@"testing volPath '%@'", path);

      if ([iPodLibrary isIPodAtMountPoint:path]) {
        lib = [[iPodLibrary alloc] initWithMountPoint:path];
      }
      else if ([JBiPodLibrary isIPodAtMountPoint:path]) {
        lib = [[JBiPodLibrary alloc] initWithMountPoint:path];
      }
      else if ([IPhoneDiskIPodLibrary isIPodAtMountPoint:path]) {
        lib = [[IPhoneDiskIPodLibrary alloc] initWithMountPoint:path];
      }
      
      if (lib) {
        [self addLibrary:lib];
        [lib release];
        lib = nil;
      }
    }
    
    // mount/unmount registration
    NSNotificationCenter *nc = [[NSWorkspace sharedWorkspace]
                                             notificationCenter];
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

- (void)willUnmount {
  NSNotificationCenter *nc;

  if (doDebug)
    NSLog(@"iTunesFileSystem will unmount now");

  nc = [[NSWorkspace sharedWorkspace] notificationCenter];
  [nc removeObserver:self];

  [self->volMap release];

  NSAutoreleasePool *localPool = [NSAutoreleasePool new];

  // close all libraries
  NSArray    *libs    = [self->libMap allValues];
  NSUInteger i, count = [libs count];
  for (i = 0; i < count; i++) {
    [[libs objectAtIndex:i] close];
  }

  [localPool release];

  [self->libMap release];
	
  [super willUnmount];
}

- (void)didMountRemovableDevice:(NSNotification *)_notif {
  NSString *path;

  path = [[_notif userInfo] objectForKey:@"NSDevicePath"];
  if ([iPodLibrary isIPodAtMountPoint:path] ||
      [JBiPodLibrary isIPodAtMountPoint:path]) 
  {
    iTunesLibrary *lib;
    BOOL          prevShowLibraries;

    prevShowLibraries = [self showLibraries];
    if (doDebug) NSLog(@"Will add library for iPod at path: %@", path);
    if ([iPodLibrary isIPodAtMountPoint:path])
      lib = [[iPodLibrary alloc] initWithMountPoint:path];
    else
      lib = [[JBiPodLibrary alloc] initWithMountPoint:path];
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
  NSString *path = [_lib mountPoint];
  if (path) {
    if ([self->volMap objectForKey:path])
      return; // drop duplicates
    [self->volMap setObject:_lib forKey:path];
  }
  [self->libMap setObject:_lib forKey:[_lib name]];

  if (doDebug)
    NSLog(@"did add library %@", _lib);
}

- (void)removeLibrary:(iTunesLibrary *)_lib {
  if (doDebug)
    NSLog(@"will remove library %@", _lib);

  NSString *path = [_lib mountPoint];
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

/* FUSEOFS */

- (id)lookupPathComponent:(NSString *)_pc inContext:(id)_ctx {
  // TODO: add fake Spotlight entries
  NSObject *obj;
  
  if (![self showLibraries])
    obj = [[self->libMap allValues] lastObject];
  else
    obj = self->libMap;

  return [obj lookupPathComponent:_pc inContext:_ctx];
}

- (NSArray *)directoryContents {
  // TODO: fake Spotlight database
  NSObject *obj;
  
  if (![self showLibraries])
    obj = [[self->libMap allValues] lastObject];
  else
    obj = self->libMap;
  return [obj directoryContents];
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

/* optional */

- (BOOL)usesResourceForks {
  return YES;
}

/* Finder in ver > 10.4 is braindead, only displays filesystems
 * marked as "local" in sidebar
 */
- (BOOL)needsLocalOption {
  NSString *osVer = [[NSProcessInfo processInfo] operatingSystemVersionString];
  
  if ([osVer rangeOfString:@"10.4"].length != 0) return NO;
  return YES;
}

- (BOOL)wantsAllowOtherOption {
  return allowOtherOption;
}

- (NSArray *)fuseOptions {
  NSMutableArray *os;
  
  os = [[[super fuseOptions] mutableCopy] autorelease];
  
#if 0
  // careful (fuse will be pretty slow when in use)!
  // NOTE: I guess this is obsolete by now, should use dtrace for the
  // purpose of debugging fuse
  [os addObject:@"debug"];
#endif
  
  // TODO: pretty lame, couldn't we set this using reflection on FS mutability?
  [os addObject:@"rdonly"];

#if 0
  // EXP: use this only for experiments
  [os addObject:@"daemon_timeout=10"];
#endif

#if 0
  // TODO: (Dan) explain why we would need that option
  // we know all filesizes beforehand from the various libraries' metadata,
  // MUST we really guarantee that these are indeed correct?
  [os addObject:@"direct_io"];
#endif

  // TODO: get this from user defaults?
  [os addObject:@"volname=iTunesFS"];

  if ([self wantsAllowOtherOption])
    [os addObject:@"allow_other"];

  if ([self needsLocalOption])
    [os addObject:@"local"];
  return os;
}

- (NSString *)iconFileForPath:(NSString *)_path {
  if ([_path isEqualToString:@"/"]) return fsIconPath;
  return nil;
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
