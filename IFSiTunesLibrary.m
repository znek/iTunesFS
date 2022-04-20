/*
  Copyright (c) 2007-2015, Marcus Müller <znek@mulle-kybernetik.com>.
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
#import <AppKit/AppKit.h>
#import "IFSiTunesLibrary.h"

#import "NSObject+FUSEOFS.h"
#import "NSString+Extensions.h"

#import "IFSiTunesPlaylist.h"
#import "IFSM3UPlaylist.h"
#import "IFSiTunesTrack.h"
#import "IFSFormatter.h"
#import "FUSEOFSMemoryContainer.h"
#ifndef GNU_GUI_LIBRARY
#import "NSImage+IconData.h"
#endif
#ifndef NO_WATCHDOG
#import "Watchdog.h"
#endif

@implementation IFSiTunesLibrary

static BOOL doDebug       = NO;
static BOOL useCategories = NO;
static BOOL mimicIPodNav  = NO;
static BOOL useBurnFolderNames = YES;
static BOOL useM3UPlaylists = NO;

static NSString *libraryPath     = nil;
static NSData   *libraryIconData = nil;
static NSString *kPlaylists      = @"Playlists";
static NSString *kM3UPlaylists   = @"M3UPlaylists";
static NSString *kCompilations   = @"Compilations";
static NSString *kArtists        = @"Artists";
static NSString *kAlbums         = @"Albums";
static NSString *kSongs          = @"Songs";
static NSString *kUnknown        = @"Unknown";
static NSString *kAll            = @"All";

+ (void)initialize {
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;

  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  doDebug            = [ud boolForKey:@"iTunesFileSystemDebugEnabled"];
  useCategories      = [ud boolForKey:@"UseCategories"];
  useBurnFolderNames = [ud boolForKey:@"UseBurnFoldersInFinder"];
  useM3UPlaylists    = [ud boolForKey:@"UseM3UPlaylists"];
  libraryPath        = [[[ud stringForKey:@"Library"] stringByStandardizingPath]
                                                      copy];
  if (!libraryPath) {
    // retrieve standard library path from iApps's defaults
    [ud synchronize];

    NSArray *dbs = [[ud persistentDomainForName:@"com.apple.iApps"]
                        objectForKey:@"iTunesRecentDatabases"];
    if ([dbs count] > 0) {
      NSURL *url = [NSURL URLWithString:[dbs objectAtIndex:0]];
      if ([url isFileURL]) {
        libraryPath = [[url path] copy];
        if (doDebug)
          NSLog(@"LibraryPath retrieved via iApps default: %@", libraryPath);
      }
    }

    if (!libraryPath) {
      // fallback to simple heuristic, if above plan didn't work
      // (for whatever reason)
      libraryPath = [[NSHomeDirectory() stringByAppendingString:
                                        @"/Music/iTunes/iTunes Music Library.xml"]
                                        copy];
      if (doDebug)
        NSLog(@"LibraryPath determined via simple heuristic: %@", libraryPath);
    }
  }
  else {
    if (doDebug)
      NSLog(@"LibraryPath set via 'Library' user default: %@", libraryPath);
  }

  /* GNUstep's AppKit doesn't know Apple icons */
#ifndef GNU_GUI_LIBRARY
  libraryIconData = [[[[NSWorkspace sharedWorkspace]
                                    iconForFile:@"/Applications/iTunes.app"]
                                    icnsDataWithWidth:512] copy];
#endif

  kPlaylists    = [[NSLocalizedString(@"Playlists",    "Playlists")
                                      properlyEscapedFSRepresentation] copy];
  kM3UPlaylists = [[NSLocalizedString(@"M3UPlaylists", "M3UPlaylists")
                                      properlyEscapedFSRepresentation] copy];
  kAlbums       = [[NSLocalizedString(@"Albums",       "Albums")
                                      properlyEscapedFSRepresentation] copy];
  kCompilations = [[NSLocalizedString(@"Compilations", "Compilations")
								                      properlyEscapedFSRepresentation] copy];
  kArtists      = [[NSLocalizedString(@"Artists",      "Artists")
                                      properlyEscapedFSRepresentation] copy];
  kSongs        = [[NSLocalizedString(@"Songs",        "Songs")
                                      properlyEscapedFSRepresentation] copy];
  kUnknown      = [[NSLocalizedString(@"Unknown",      "Unknown")
                                      properlyEscapedFSRepresentation] copy];
  kAll          = [[NSLocalizedString(@"All",          "All")
                                      properlyEscapedFSRepresentation] copy];

  if (doDebug && useCategories)
    NSLog(@"Using categories (virtual folder hierarchy)");
}

- (id)init {
  self = [super init];
  if (self) {
    self->plMap    = [[FUSEOFSMemoryContainer alloc] initWithCapacity:128];
    self->m3uMap   = [[FUSEOFSMemoryContainer alloc] initWithCapacity:128];
    self->trackMap = [[NSMutableDictionary alloc] initWithCapacity:10000];
    if (useCategories) {
      self->virtMap = [[FUSEOFSMemoryContainer alloc] init];
      [self->virtMap createContainerNamed:kAlbums  withAttributes:nil];
      [self->virtMap createContainerNamed:kArtists withAttributes:nil];
      [self->virtMap createContainerNamed:kCompilations withAttributes:nil];
    }
    [self reload];
#ifndef NO_WATCHDOG
    [[Watchdog sharedWatchdog] watchLibrary:self];
#endif
  }
  return self;
}

- (void)dealloc {
  [self close];
  [self->name     release];
  [self->plMap    release];
  [self->m3uMap   release];
  [self->trackMap release];
  [self->virtMap  release];
  [super dealloc];
}

/* setup */

- (void)reload {
  if (doDebug)
    NSLog(@"%s", __PRETTY_FUNCTION__);

  [self->plMap    removeAllObjects];
  [self->m3uMap   removeAllObjects];
  [self->trackMap removeAllObjects];

  NSData *plist = [NSData dataWithContentsOfFile:[self libraryPath]];
  NSAssert1(plist != nil, @"Couldn't read contents of %@!",
                          [self libraryPath]);

  NSDictionary  *lib;
#if __MAC_OS_X_VERSION_MAX_ALLOWED < 101000
  lib = [NSPropertyListSerialization propertyListFromData:plist
                                     mutabilityOption:NSPropertyListImmutable
                                     format:NULL
                                     errorDescription:NULL];
#else
  lib = [NSPropertyListSerialization propertyListWithData:plist
                                     options:NSPropertyListImmutable
                                     format:NULL
                                     error:NULL];
#endif
  NSAssert1(lib != nil, @"Couldn't parse contents of %@ - wrong format?!",
                        [self libraryPath]);

  [self->name release];
  self->name = [[NSString stringWithFormat:@"iTunes (v%@)",
                          [lib objectForKey:@"Application Version"]] copy];

  NSDictionary *tracks   = [lib objectForKey:@"Tracks"];
  NSArray      *trackIDs = [tracks allKeys];
  NSUInteger   count     = [trackIDs count];
  for (NSUInteger i = 0; i < count; i++) {
    NSString     *trackID;
    NSDictionary *rep;
    IFSiTunesTrack  *track;

    trackID = [trackIDs objectAtIndex:i];
    rep     = [tracks objectForKey:trackID];
    track   = [[IFSiTunesTrack alloc] initWithLibraryRepresentation:rep];
    if ([track isUsable])
      [self->trackMap setObject:track forKey:trackID];
    [track release];
  }

  NSArray *playlists = [lib objectForKey:@"Playlists"];
  count = [playlists count];
  NSMutableDictionary *idPlMap = [[NSMutableDictionary alloc]
                                                       initWithCapacity:count];

  for (NSUInteger i = 0; i < count; i++) {
    NSDictionary *plRep = [playlists objectAtIndex:i];
    IFSiTunesPlaylist *pl = [[IFSiTunesPlaylist alloc]
                                                initWithLibraryRepresentation:plRep
                                                lib:self];

    // only record top-level playlist, if playlist isn't a folder itself
    if (![pl parentId]) {
      [self->plMap setItem:pl
                   forName:[self burnFolderNameFromFolderName:[pl name]]];
    }

    id plId = [pl persistentId];
    if (plId)
      [idPlMap setObject:pl forKey:plId];
    [pl release];
  }

  // connect children to their parents
  if ([idPlMap count]) {
    NSArray *ids = [idPlMap allKeys];
    count = [ids count];
    for (NSUInteger i = 0; i < count; i++) {
      id plId = [ids objectAtIndex:i];
      IFSiTunesPlaylist *pl = [idPlMap objectForKey:plId];
      id parentId = [pl parentId];
      if (parentId) {
        IFSiTunesPlaylist *parent = [idPlMap objectForKey:parentId];
        if (parent) {
          [parent addChild:pl
                  withName:[self burnFolderNameFromFolderName:[pl name]]];
        }
        else {
          NSLog(@"ERROR: didn't find parent playlist of '%@'?!", pl);
        }
      }
    }
  }

  if (useM3UPlaylists) {
    for (IFSiTunesPlaylist *pl in [idPlMap allValues]) {
      if (![[pl allTracks] count])
        continue;

      IFSM3UPlaylist *m3uPl = [[IFSM3UPlaylist alloc]
                                               initWithPlaylist:pl
                                               useRelativePaths:NO];
      [self->m3uMap setItem:m3uPl forName:[m3uPl fileName]];
      [m3uPl release];
    }
  }

  [idPlMap release];
  [self reloadVirtualMaps];
}

- (void)reloadVirtualMaps {
  if (!useCategories) return;

  [self->virtMap removeItemNamed:kPlaylists];
  [self->virtMap removeItemNamed:kM3UPlaylists];
  [self->virtMap removeItemNamed:kSongs];

  if ([self->plMap count] == 1) {
    [self->virtMap setItem:[[self->plMap allItems] lastObject]
                   forName:kSongs];
  }
  else {
    [self->virtMap setItem:self->plMap forName:kPlaylists];
    if (useM3UPlaylists)
      [self->virtMap setItem:self->m3uMap forName:kM3UPlaylists];
  }

  NSString *fmt = [[NSUserDefaults standardUserDefaults]
                                   stringForKey:@"AlbumsTrackFormat"];
  IFSFormatter *formatter = [[IFSFormatter alloc]
                                                     initWithFormatString:fmt];


  FUSEOFSMemoryContainer *albums  = [self->virtMap lookupPathComponent:kAlbums
                                                   inContext:self];
  FUSEOFSMemoryContainer *artists = [self->virtMap lookupPathComponent:kArtists
                                                   inContext:self];
  FUSEOFSMemoryContainer *compilations = [self->virtMap lookupPathComponent:kCompilations
                                                        inContext:self];

  [albums  removeAllObjects];
  [artists removeAllObjects];
  [compilations removeAllObjects];

  NSArray *tracks = [self->trackMap allValues];
  NSUInteger count  = [tracks count];
  for (NSUInteger i = 0; i < count; i++) {
    IFSiTunesTrack *track = [tracks objectAtIndex:i];

    NSString *formattedName = [formatter stringValueByFormattingObject:track];
    NSString *artist = [track artist];
    if (!artist)
      artist = kUnknown;
    NSString *album  = [track album];
    if (!album)
      album  = kUnknown;

    NSString *formattedArtist = [self burnFolderNameFromFolderName:artist];
    NSString *formattedAlbum  = [self burnFolderNameFromFolderName:album];

    BOOL isNew = [artists createContainerNamed:formattedArtist withAttributes:nil];
    FUSEOFSMemoryContainer *artistAlbums = [artists lookupPathComponent:formattedArtist
                                                    inContext:self];
    if (isNew)
      [artists setItem:artistAlbums forName:formattedArtist];

    isNew = [artistAlbums createContainerNamed:formattedAlbum withAttributes:nil];
    FUSEOFSMemoryContainer *albumTracks = [artistAlbums lookupPathComponent:formattedAlbum
                                                        inContext:self];
    if (isNew)
      [artistAlbums setItem:albumTracks forName:formattedAlbum];
    [albumTracks setItem:track forName:formattedName];

    // now, for albums only
    isNew = [albums createContainerNamed:formattedAlbum withAttributes:nil];
    albumTracks = [albums lookupPathComponent:formattedAlbum inContext:self];
    if (isNew)
      [albums setItem:albumTracks forName:formattedAlbum];
    [albumTracks setItem:track forName:formattedName];
  }

  [formatter release];

  NSArray *allAlbums;

  allAlbums = [albums allItems];
  count     = [allAlbums count];
  for (NSUInteger i = 0; i < count; i++) {
    FUSEOFSMemoryContainer *thisAlbum;
    thisAlbum = [allAlbums objectAtIndex:i];
    tracks    = [thisAlbum allItems];

    NSString *artist = [[tracks objectAtIndex:0] artist];
    if (!artist) artist = kUnknown;
    NSString *album = [[tracks objectAtIndex:0] album];
    if (album) {
      NSUInteger tCount, j;

      tCount = [tracks count];
      if (tCount > 1) {
        NSString *formattedAlbum = [self burnFolderNameFromFolderName:album];
        for (j = 1; j < tCount; j++) {
          IFSiTunesTrack *track;
          NSString    *tArtist;

          track   = [tracks objectAtIndex:j];
          tArtist = [track artist];
          if (!tArtist) tArtist = kUnknown;
          if (![artist isEqualToString:tArtist]) { 
            [compilations setItem:thisAlbum forName:formattedAlbum];
            break;
          }
        }
      }
    }
  }

  if (mimicIPodNav) {
    /* optimize artistAlbums hierarchy, insert "All" if there is more than
     * one album per artist
     */
    NSArray *allAlbums = [artists allItems];
    count = [allAlbums count];
    for (NSUInteger i = 0; i < count; i++) {
      FUSEOFSMemoryContainer *artistAlbums = [allAlbums objectAtIndex:i];
      NSUInteger aCount = [artistAlbums count];
      if (aCount > 1) {
        FUSEOFSMemoryContainer *allTracks = [[FUSEOFSMemoryContainer alloc] initWithCapacity:10 * aCount];
        [artistAlbums setItem:allTracks forName:kAll];
        [allTracks release];

        NSArray *allArtistAlbums = [artistAlbums allItems];
        for (NSUInteger k = 0; k < aCount; k++) {
          FUSEOFSMemoryContainer *albumTracks = [allArtistAlbums objectAtIndex:k];
          /* NOTE:
           * This doesn't avoid collisions!!
           * It's unsuitable for COPYING content, though browsing does work
           * to some extent...
           */
          [allTracks addEntriesFromContainer:albumTracks];
        }
      }
    }
  }
  
}

- (void)close {
  if (doDebug)
    NSLog(@"closing library: %@", self);

#ifndef NO_WATCHDOG
  [[Watchdog sharedWatchdog] forgetLibrary:self];
#endif
}

/* accessors */

- (NSString *)name {
  if (!doDebug) return @"iTunes";
  return self->name;
}
- (NSString *)libraryPath {
  return libraryPath;
}
- (NSString *)mountPoint {
  return nil;
}

- (NSArray *)playlistNames {
  return [self->plMap containerContents];
}
- (IFSiTunesPlaylist *)playlistNamed:(NSString *)_plName {
  return [self->plMap lookupPathComponent:_plName inContext:self];
}


- (IFSiTunesTrack *)trackWithID:(id)_trackID {
  return [self->trackMap objectForKey:_trackID];
}

/* FUSEOFS */

- (id)lookupPathComponent:(NSString *)_pc inContext:(id)_ctx {
  if (!useCategories) {
    NSUInteger count = [self->plMap count];
    if (count == 0) return nil; // no playlists, no entries
    if (count == 1) {
      // hide single playlist altogether (i.e. iPod shuffle)
      return [[[self->plMap allItems] lastObject] lookupPathComponent:_pc
                                                  inContext:_ctx];
    }
    return [self playlistNamed:_pc];
  }
  return [self->virtMap lookupPathComponent:_pc inContext:_ctx];
}

- (NSArray *)containerContents {
  if (!useCategories) {
    if ([self->plMap count] != 1)
      return [self playlistNames];
    // return all tracknames in case there's just one playlist (iPod shuffle)
    return [[[self->plMap allItems] lastObject] containerContents];
  }
  return [self->virtMap containerContents];
}

- (NSData *)iconData {
  return libraryIconData;
}

- (BOOL)isContainer {
  return YES;
}

/* burn folder support */

- (id)burnFolderNameFromFolderName:(NSString *)_s {
  if (!useBurnFolderNames) return _s;
  return [_s stringByAppendingPathExtension:@"fpbf"];
}

/* debugging */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%s %p: name:%@ path:%@>",
                                    object_getClassName(self), self,
                                    [self name], [self libraryPath]];
}

@end /* IFSiTunesLibrary */

// FIXME
@implementation IFSiTunesLibrary (Private)
- (BOOL)doDebug {
  return doDebug;
}
- (BOOL)useM3UPlaylists {
  return useM3UPlaylists;
}
@end
