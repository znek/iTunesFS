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
#import "NSArray+Extensions.h"

@implementation iTunesFileSystem

static NSString *fsIconPath = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  NSBundle    *mb;
  
  if (didInit) return;
  didInit    = YES;
  mb         = [NSBundle mainBundle];
  fsIconPath = [[mb pathForResource:@"iTunesFS" ofType:@"icns"] copy];
  NSAssert(fsIconPath != nil, @"Couldn't find iTunesFS.icns!");
}

/* notifications */

- (void)fuseWillMount {
  iTunesLibrary *lib;

  self->libs   = [[NSMutableArray alloc] initWithCapacity:3];
  self->libMap = [[NSMutableDictionary alloc] initWithCapacity:3];

  // add default library
  lib = [[iTunesLibrary alloc] init];
  [self addLibrary:lib];
  [lib release];
}

- (void)fuseDidUnmount {
  [self->libs release];
}

- (void)addLibrary:(iTunesLibrary *)_lib {
  [self->libs addObject:_lib];
  [self->libMap setObject:_lib forKey:[_lib name]];
}

/* required stuff */

/* currently we have this scheme:
 * Libraries / Playlists / Tracks
 */
- (NSArray *)directoryContentsAtPath:(NSString *)_path {
  NSArray       *path;
  iTunesLibrary *lib;

  path = [_path pathComponents];
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

  path         = [_path pathComponents];
  *isDirectory = [path isDirectoryPath];

  if ([path isRootDirectory]) return YES;

  lib = [self->libMap objectForKey:[path libraryName]];
  if ([path isLibraryDirectory]) return lib != nil;
  else if([path isPlaylistDirectory])
    return [[lib playlistNames] containsObject:[path playlistName]];
  else
    return [lib isValidTrackName:[path trackName]
                inPlaylistNamed:[path playlistName]];
}

- (NSDictionary *)fileAttributesAtPath:(NSString *)_path {
  NSArray       *path;
  iTunesLibrary *lib;
  
  path = [_path pathComponents];
  if ([path isDirectoryPath])
    return [super fileAttributesAtPath:_path];

  lib = [self->libMap objectForKey:[path libraryName]];
  return [lib fileAttributesForTrackWithPrettyName:[path trackName]
              inPlaylistNamed:[path playlistName]];
}

- (NSData *)contentsAtPath:(NSString *)_path {
  NSArray       *path;
  iTunesLibrary *lib;
  
  path = [_path pathComponents];
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
  
  path = [_path pathComponents];
  if ([path isLibraryDirectory])
    return [[self->libMap objectForKey:[path libraryName]] icon];
  return nil;
}

@end
