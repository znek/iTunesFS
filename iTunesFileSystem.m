/*
  Copyright (c) 2007, Marcus MŸller <znek@mulle-kybernetik.com>.
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

@interface iTunesFileSystem (Private)
- (void)addLibrary:(iTunesLibrary *)_lib;
- (void)removeLibrary:(iTunesLibrary *)_lib;
- (void)didMountRemovableDevice:(NSNotification *)_notif;
- (void)didUnmountRemovableDevice:(NSNotification *)_notif;
- (NSArray *)pathFromFSPath:(NSString *)_path;
@end

@implementation iTunesFileSystem

static BOOL     doDebug     = NO;
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
  ignoreIPods = [ud boolForKey:@"NoIPods"];
  mb          = [NSBundle mainBundle];
  fsIconPath  = [[mb pathForResource:@"iTunesFS" ofType:@"icns"] copy];
  NSAssert(fsIconPath != nil, @"Couldn't find iTunesFS.icns!");
}

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

    if (doDebug) NSLog(@"Will add library for iPod at path: %@", path);
    lib = [[iPodLibrary alloc] initWithMountPoint:path];
    [self addLibrary:lib];
    [lib release];
  }
}

- (void)didUnmountRemovableDevice:(NSNotification *)_notif {
  NSString      *path;
  iTunesLibrary *lib;

  path = [[_notif userInfo] objectForKey:@"NSDevicePath"];
  lib  = [self->volMap objectForKey:path];
  if (lib) {
    if (doDebug)
      NSLog(@"Will remove library for unmounted iPod at path: %@", path);
    [self removeLibrary:lib];
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

- (NSArray *)pathFromFSPath:(NSString *)_path {
  NSArray *path;

  path = [_path pathComponents];
  if (ignoreIPods) {
    NSMutableArray *fakePath;
    
    /* When iPods are ignored by default, we suppress the "Libraries"
    * hierarchy altogether as it makes no sense.
    * This is done by faking the only existing library into the path.
    */
    fakePath = [path mutableCopy];
    [fakePath insertObject:[[self->libMap allKeys] lastObject] atIndex:1];
    path = [fakePath autorelease];
  }
  return path;
}

/* required stuff */

/* currently we have this scheme:
 * Libraries / Playlists / Tracks
 */
- (NSArray *)directoryContentsAtPath:(NSString *)_path {
  NSArray       *path;
  iTunesLibrary *lib;

  if (doDebug)
    NSLog(@"%s path:%@", __PRETTY_FUNCTION__, _path);

  path = [self pathFromFSPath:_path];
  if ([path isRootDirectory])
    return [self->libMap allKeys];

  lib = [self->libMap objectForKey:[path libraryName]];
  if ([path isLibraryDirectory])
    return [lib playlistNames];
  return [lib trackNamesForPlaylistNamed:[path playlistName]];
}

- (BOOL)fileExistsAtPath:(NSString *)_path isDirectory:(BOOL *)isDirectory {
  NSArray       *path;
  iTunesLibrary *lib;

  if (doDebug)
    NSLog(@"%s path:%@", __PRETTY_FUNCTION__, _path);

  path         = [self pathFromFSPath:_path];
  *isDirectory = [path isDirectoryPath];

  if ([path isRootDirectory]) return YES;

  lib = [self->libMap objectForKey:[path libraryName]];
  if ([path isLibraryDirectory])
    return lib != nil;
  else if([path isPlaylistDirectory])
    return [[lib playlistNames] containsObject:[path playlistName]];
  else
    return [lib isValidTrackName:[path trackName]
                inPlaylistNamed:[path playlistName]];
}

- (NSDictionary *)fileAttributesAtPath:(NSString *)_path {
  NSArray       *path;
  iTunesLibrary *lib;
  
  if (doDebug)
    NSLog(@"%s path:%@", __PRETTY_FUNCTION__, _path);

  path = [self pathFromFSPath:_path];
  if ([path isDirectoryPath])
    return [super fileAttributesAtPath:_path];

  lib = [self->libMap objectForKey:[path libraryName]];
  return [lib fileAttributesForTrackWithPrettyName:[path trackName]
              inPlaylistNamed:[path playlistName]];
}

- (NSData *)contentsAtPath:(NSString *)_path {
  NSArray       *path;
  iTunesLibrary *lib;

  if (doDebug)
    NSLog(@"%s path:%@", __PRETTY_FUNCTION__, _path);

  path = [self pathFromFSPath:_path];
  if ([path isDirectoryPath]) return nil;

  lib = [self->libMap objectForKey:[path libraryName]];
  return [lib fileContentForTrackWithPrettyName:[path trackName]
              inPlaylistNamed:[path playlistName]];
}

/* optional */

#if 0
- (BOOL)shouldMountInFinder {
  return YES;
}
#endif

- (BOOL)usesResourceForks {
  return YES;
}

- (NSString *)iconFileForPath:(NSString *)_path {
  if ([_path isEqualToString:@"/"]) return fsIconPath;
  return nil;
}

- (NSImage *)iconForPath:(NSString *)_path {
  NSArray *path;
  
  path = [self pathFromFSPath:_path];
  if ([path isLibraryDirectory])
    return [[self->libMap objectForKey:[path libraryName]] icon];
  return nil;
}

- (NSDictionary *)fileSystemAttributesAtPath:(NSString *)_path {
  if ([_path isEqualToString:@"/"]) {
    NSMutableDictionary *attrs;
    
    attrs = [[NSMutableDictionary alloc] initWithCapacity:2];
    //    [attrs setObject:defaultSize forKey:NSFileSystemSize];
    [attrs setObject:[NSNumber numberWithInt:0] forKey:NSFileSystemFreeSize];
    return [attrs autorelease];
  }
  return nil;
}

@end
