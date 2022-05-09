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
#import "AppKit/AppKit.h"
#import "IFSiTunesLibrary.h"
#import "IFSiPodLibrary.h"
#import "IFSJBiPodLibrary.h"
#ifndef NO_OSX_ADDITIONS
#import "IFSiTunesFrameworkLibrary.h"
#endif

#import "NSObject+FUSEOFS.h"
#import "FUSEOFSMemoryContainer.h"
#import "IFSFormatFile.h"
#import "NSMutableArray+Extensions.h"

@interface iTunesFileSystem (Private)
- (void)addLibrary:(IFSiTunesLibrary *)_lib;
- (void)removeLibrary:(IFSiTunesLibrary *)_lib;
- (void)didMountRemovableDevice:(NSNotification *)_notif;
- (void)willUnmountRemovableDevice:(NSNotification *)_notif;
- (void)didUnmountRemovableDevice:(NSNotification *)_notif;

- (BOOL)showLibraries;

- (void)reload;

- (NSArray *)pathFromFSPath:(NSString *)_path;
- (id)lookupPath:(NSString *)_path;

- (BOOL)needsLocalOption;
- (BOOL)wantsAllowOtherOption;

@end

@implementation iTunesFileSystem

static BOOL doDebug          = NO;
static BOOL ignoreITunes     = NO;
static BOOL ignoreAppleMusic = NO;
static BOOL ignoreIPods      = NO;
static BOOL allowOtherOption = NO;
static BOOL showFormatFiles  = YES;
static BOOL useCategories    = YES;

static NSString *fsIconPath      = nil;
static NSArray  *fakeVolumePaths = nil;
static NSString *playlistsTrackFormatFileName = @"PlaylistsTrackFormat.txt";
static NSString *albumsTrackFormatFileName    = @"AlbumsTrackFormat.txt";

+ (void)initialize {
  static BOOL didInit = NO;

  if (didInit) return;

  didInit = YES;

  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  doDebug          = [ud boolForKey:@"iTunesFileSystemDebugEnabled"];
  ignoreITunes     = [ud boolForKey:@"NoITunes"];
  ignoreAppleMusic = [ud boolForKey:@"NoAppleMusic"];
  ignoreIPods      = [ud boolForKey:@"NoIPods"];
  allowOtherOption = [ud boolForKey:@"FUSEOptionAllowOther"];
  showFormatFiles  = [ud boolForKey:@"ShowFormatFiles"];
  useCategories    = [ud boolForKey:@"UseCategories"];

  if (ignoreITunes && ignoreIPods)
    NSLog(@"ERROR: ignoring iTunes and iPods doesn't make sense at all.");
  fakeVolumePaths = [[ud arrayForKey:@"iPodMountPoints"] copy];
#ifndef GNU_GUI_LIBRARY
  NSBundle *mb = [NSBundle mainBundle];
  fsIconPath = [[mb pathForResource:@"iTunesFS" ofType:@"icns"] copy];
  NSAssert(fsIconPath != nil, @"Couldn't find iTunesFS.icns!");
#endif
}

/* NSObject(GMUserFileSystemLifecycle) */

- (void)willMount {
  if (doDebug)
    NSLog(@"iTunesFileSystem will mount now");

  self->libMap = [[NSMutableDictionary alloc] initWithCapacity:3];
  self->volMap = [[NSMutableDictionary alloc] initWithCapacity:3];

  self->playlistsTrackFormatFile =
    [[IFSFormatFile alloc] initWithDefaultTemplate:@"PlaylistsTrackFormat"
                              templateId:nil];
  self->albumsTrackFormatFile =
    [[IFSFormatFile alloc] initWithDefaultTemplate:@"AlbumsTrackFormat"
                              templateId:nil];
  self->shadowFolder = [[FUSEOFSMemoryContainer alloc] init];

  IFSiTunesLibrary *lib;

  // add default library
  if ([self useIFSiTunesLibrary]) {
    lib = [[IFSiTunesLibrary alloc] init];
    [self addLibrary:lib];
    [lib release];
  }
#ifndef NO_OSX_ADDITIONS
  if ([self useITunesFrameworkLibrary]) {
    lib = [[IFSiTunesFrameworkLibrary alloc] init];
    [self addLibrary:lib];
    [lib release];
  }
#endif

  if (!ignoreIPods) {
#if __MAC_OS_X_VERSION_MAX_ALLOWED < 101000
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];

    NSMutableArray *volPaths =
      [NSMutableArray arrayWithArray:[ws mountedLocalVolumePaths]];
    [volPaths addObjectsFromArrayIfAbsent:[ws mountedRemovableMedia]];
#else
    NSMutableArray *volPaths = [NSMutableArray array];
#ifndef GNUSTEP_BASE_LIBRARY
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray *urls = [fm mountedVolumeURLsIncludingResourceValuesForKeys:nil
                        options:0];
    NSUInteger uCount = [urls count];
    for (NSUInteger i = 0; i < uCount; i++) {
      NSURL *url = [urls objectAtIndex:i];
      if ([url isFileURL]) {
        [volPaths addObjectIfAbsent:[url path]];
      }
    }
#endif
#endif

    if (fakeVolumePaths)
       [volPaths addObjectsFromArrayIfAbsent:fakeVolumePaths];

    lib = nil;
    NSUInteger count = [volPaths count];
    for (NSUInteger i = 0; i < count; i++) {
      NSString *path = [volPaths objectAtIndex:i];
      if (doDebug)
        NSLog(@"testing volPath '%@'", path);

      if ([IFSiPodLibrary isIPodAtMountPoint:path]) {
        lib = [[IFSiPodLibrary alloc] initWithMountPoint:path];
      }
      else if ([IFSJBiPodLibrary isIPodAtMountPoint:path]) {
        lib = [[IFSJBiPodLibrary alloc] initWithMountPoint:path];
      }
      else if ([IPhoneDiskIPodLibrary isIPodAtMountPoint:path]) {
        lib = [[IPhoneDiskIPodLibrary alloc] initWithMountPoint:path];
      }
      else if ([JBiPhoneDiskIPodLibrary isIPodAtMountPoint:path]) {
        lib = [[JBiPhoneDiskIPodLibrary alloc] initWithMountPoint:path];
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

  [self->playlistsTrackFormatFile release];
  [self->albumsTrackFormatFile    release];
  [self->shadowFolder release];
  
  [super willUnmount];
}

- (void)didMountRemovableDevice:(NSNotification *)_notif {
  NSString *path;

  path = [[_notif userInfo] objectForKey:@"NSDevicePath"];
  if ([IFSiPodLibrary isIPodAtMountPoint:path] ||
      [IFSJBiPodLibrary isIPodAtMountPoint:path]) 
  {
    BOOL prevShowLibraries = [self showLibraries];
    if (doDebug) NSLog(@"Will add library for iPod at path: %@", path);

    IFSiTunesLibrary *lib;
    if ([IFSiPodLibrary isIPodAtMountPoint:path])
      lib = [[IFSiPodLibrary alloc] initWithMountPoint:path];
    else
      lib = [[IFSJBiPodLibrary alloc] initWithMountPoint:path];
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
  NSString *path = [[_notif userInfo] objectForKey:@"NSDevicePath"];
  IFSiTunesLibrary *lib  = [self->volMap objectForKey:path];
  if (lib) {
    if (doDebug)
      NSLog(@"Will close library for unmounting iPod at path: %@", path);
    [lib close];
  }
}

- (void)didUnmountRemovableDevice:(NSNotification *)_notif {
  NSString *path = [[_notif userInfo] objectForKey:@"NSDevicePath"];
  IFSiTunesLibrary *lib = [self->volMap objectForKey:path];
  if (lib) {
    BOOL prevShowLibraries = [self showLibraries];

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

- (void)addLibrary:(IFSiTunesLibrary *)_lib {
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

- (void)removeLibrary:(IFSiTunesLibrary *)_lib {
  if (doDebug)
    NSLog(@"will remove library %@", _lib);

  [_lib close];

  NSString *path = [_lib mountPoint];
  if (path)
    [self->volMap removeObjectForKey:path];
  [self->libMap removeObjectForKey:[_lib name]];
}

/* private */

#ifndef NO_OSX_ADDITIONS

- (BOOL)hasAppleMusic {
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101000
  NSOperatingSystemVersion vinfo = [[NSProcessInfo processInfo] operatingSystemVersion];
  const double version = (double)vinfo.majorVersion + 0.01 * (double)vinfo.minorVersion + 0.0001 * (double)vinfo.patchVersion;
  return (version >= 10.15) ? YES : NO;
#else
  return NO;
#endif
}

- (BOOL)useITunesFrameworkLibrary {
  return (!ignoreAppleMusic && [self hasAppleMusic]) ? YES : NO;
}
- (BOOL)useIFSiTunesLibrary {
  if (ignoreITunes)
    return NO;
  return ![self hasAppleMusic] || ignoreAppleMusic;
}

#else

- (BOOL)useIFSiTunesLibrary {
  return !ignoreITunes;
}

#endif


- (void)reload {
  NSArray    *libs    = [self->libMap allValues];
  NSUInteger i, count = [libs count];
  for (i = 0; i < count; i++) {
    [[libs objectAtIndex:i] reload];
  }
}

- (BOOL)showLibraries {
  if (ignoreIPods) return NO;
  if ([self->libMap count] == 1) return NO;
  return YES;
}

/* FUSEOFS */

- (id)lookupPathComponent:(NSString *)_pc inContext:(id)_ctx {
  if ([_pc isEqualToString:playlistsTrackFormatFileName])
    return self->playlistsTrackFormatFile;
  else if ([_pc isEqualToString:albumsTrackFormatFileName])
    return self->albumsTrackFormatFile;

  id obj;

  if (![self showLibraries])
    obj = [[self->libMap allValues] lastObject];
  else
    obj = self->libMap;

  obj = [obj lookupPathComponent:_pc inContext:_ctx];
  if (!obj)
    obj = [self->shadowFolder lookupPathComponent:_pc inContext:_ctx];
  return obj;
}

- (NSArray *)containerContents {
  NSObject *obj;
  
  if (![self showLibraries])
    obj = [[self->libMap allValues] lastObject];
  else
    obj = self->libMap;
  
  if (showFormatFiles) {
    NSMutableArray *contents = [[NSMutableArray alloc] initWithCapacity:10];
    [contents addObjectsFromArray:[obj containerContents]];
    [contents addObject:playlistsTrackFormatFileName];
    if (useCategories)
      [contents addObject:albumsTrackFormatFileName];
    return [contents autorelease];
  }
  return [obj containerContents];
}

- (NSDictionary *)fileSystemAttributes {
  NSMutableDictionary *attrs;
  
  attrs = [[NSMutableDictionary alloc] initWithCapacity:2];
  //    [attrs setObject:defaultSize forKey:NSFileSystemSize];
  [attrs setObject:[NSNumber numberWithInt:0] forKey:NSFileSystemFreeSize];
  return [attrs autorelease];
}

- (BOOL)isContainer {
  return YES;
}
- (BOOL)isMutable {
  return YES;
}

- (BOOL)createContainerNamed:(NSString *)_name
  withAttributes:(NSDictionary *)_attrs
{
  if ([_name isEqualToString:@".Trashes"]) return NO;
  if ([_name isEqualToString:@".TemporaryItems"]) return NO;

  return [self->shadowFolder createContainerNamed:_name withAttributes:_attrs];
}

- (BOOL)writeFileNamed:(NSString *)_name withData:(NSData *)_data {
  if ([_name isEqualToString:playlistsTrackFormatFileName]) {
    [self->playlistsTrackFormatFile setFileContents:_data];
    [self reload];
    return YES;
  }
  if ([_name isEqualToString:albumsTrackFormatFileName]) {
    [self->albumsTrackFormatFile setFileContents:_data];
    if (useCategories)
      [self reload];
    return YES;
  }
  return [self->shadowFolder writeFileNamed:_name withData:_data];
}

- (BOOL)removeItemNamed:(NSString *)_name {
  if ([_name isEqualToString:playlistsTrackFormatFileName])
    return YES;
  if ([_name isEqualToString:albumsTrackFormatFileName])
    return YES;
  return [self->shadowFolder removeItemNamed:_name];
}


/* optional */

- (BOOL)usesResourceForks {
  return YES;
}

/* Finder in ver > 10.4 is braindead, only displays filesystems
 * marked as "local" in sidebar
 */
- (BOOL)needsLocalOption {
#ifndef NO_OSX_ADDITIONS

#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101000

  NSOperatingSystemVersion vinfo = [[NSProcessInfo processInfo] operatingSystemVersion];
  const double version = (double)vinfo.majorVersion + 0.01 * (double)vinfo.minorVersion + 0.0001 * (double)vinfo.patchVersion;
  return (version > 10.04) ? YES : NO;

#else

  NSString *osVer = [[NSProcessInfo processInfo] operatingSystemVersionString];
  
  if ([osVer rangeOfString:@"10.4"].length != 0) return NO;
  return YES;

#endif

#else
  return NO;
#endif
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
  
#if 0
  // EXP: use this only for experiments
  [os addObject:@"daemon_timeout=10"];
#endif

#ifndef NO_OSX_ADDITIONS
  // TODO: get this from user defaults?
  [os addObject:@"volname=iTunesFS"];
#endif

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
  [ms appendFormat:@"%s %p", object_getClassName(self), self];
  [ms appendString:@": #libs:"];
  [ms appendFormat:@"%ld", (long)[self->libMap count]];
  if (!ignoreIPods) {
    [ms appendString:@" #iPods:"];
    [ms appendFormat:@"%ld", (long)[self->volMap count]];
  }
  [ms appendString:@">"];
  return [ms autorelease];
}

@end
