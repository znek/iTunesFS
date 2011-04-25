/*
  Copyright (c) 2007-2011, Marcus Müller <znek@mulle-kybernetik.com>.
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
#import "iTunesLibrary.h"
#import <AppKit/AppKit.h>
#import "NSString+Extensions.h"
#import "iTunesPlaylist.h"
#import "iTunesTrack.h"
#import "Watchdog.h"
#import "NSObject+FUSEOFS.h"
#import "iTunesFSFormatter.h"
#ifndef GNU_GUI_LIBRARY
#import "NSImage+IconData.h"
#endif

@implementation iTunesLibrary

static BOOL doDebug       = NO;
static BOOL useCategories = NO;
static BOOL mimicIPodNav  = NO;
static BOOL useBurnFolderNames = YES;

static NSString *libraryPath     = nil;
static NSData   *libraryIconData = nil;
static NSString *kPlaylists      = @"Playlists";
static NSString	*kCompilations	 = @"Compilations";
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

  kPlaylists    = [[NSLocalizedString(@"Playlists", "Playlists")
                                      properlyEscapedFSRepresentation] copy];
  kAlbums       = [[NSLocalizedString(@"Albums",    "Albums")
                                      properlyEscapedFSRepresentation] copy];
  kCompilations = [[NSLocalizedString(@"Compilations", "Compilations")
								                      properlyEscapedFSRepresentation] copy];
  kArtists      = [[NSLocalizedString(@"Artists",   "Artists")
                                      properlyEscapedFSRepresentation] copy];
  kSongs        = [[NSLocalizedString(@"Songs",     "Songs")
                                      properlyEscapedFSRepresentation] copy];
  kUnknown      = [[NSLocalizedString(@"Unknown",   "Unknown")
                                      properlyEscapedFSRepresentation] copy];
  kAll          = [[NSLocalizedString(@"All",       "All")
                                      properlyEscapedFSRepresentation] copy];

  if (doDebug && useCategories)
    NSLog(@"Using categories (virtual folder hierarchy)");
}

- (id)init {
  self = [super init];
  if (self) {
    self->plMap    = [[NSMutableDictionary alloc] initWithCapacity:128];
    self->trackMap = [[NSMutableDictionary alloc] initWithCapacity:10000];
    if (useCategories) {
      NSMutableDictionary *tmp;

      self->virtMap = [[NSMutableDictionary alloc] initWithCapacity:4];
      tmp = [[NSMutableDictionary alloc] initWithCapacity:1000];
      [self->virtMap setObject:tmp forKey:kAlbums];
      [tmp release];
      tmp = [[NSMutableDictionary alloc] initWithCapacity:1000];
      [self->virtMap setObject:tmp forKey:kArtists];
      [tmp release];
      tmp = [[NSMutableDictionary alloc] initWithCapacity:1000];
      [self->virtMap setObject:tmp forKey:kCompilations];
      [tmp release];
    }
    [self reload];
    [[Watchdog sharedWatchdog] watchLibrary:self];
  }
  return self;
}

- (void)dealloc {
  [self close];
  [self->name     release];
  [self->plMap    release];
  [self->trackMap release];
  [self->virtMap  release];
  [super dealloc];
}

/* setup */

- (void)reload {
  NSData        *plist;
  NSDictionary  *lib;
  NSArray       *playlists;
  NSDictionary  *tracks;
  NSArray       *trackIDs;
  unsigned      i, count;

  if (doDebug)
    NSLog(@"%s", __PRETTY_FUNCTION__);

  [self->plMap    removeAllObjects];
  [self->trackMap removeAllObjects];
  plist = [NSData dataWithContentsOfFile:[self libraryPath]];
  NSAssert1(plist != nil, @"Couldn't read contents of %@!",
                          [self libraryPath]);

  lib = [NSPropertyListSerialization propertyListFromData:plist
                                     mutabilityOption:NSPropertyListImmutable
                                     format:NULL
                                     errorDescription:NULL];
  NSAssert1(lib != nil, @"Couldn't parse contents of %@ - wrong format?!",
                        [self libraryPath]);

  [self->name release];
  self->name = [[NSString stringWithFormat:@"iTunes (v%@)",
                          [lib objectForKey:@"Application Version"]] copy];

  tracks    = [lib objectForKey:@"Tracks"];
  trackIDs  = [tracks allKeys];
  count     = [trackIDs count];
  for (i = 0; i < count; i++) {
    NSString     *trackID;
    NSDictionary *rep;
    iTunesTrack  *track;

    trackID = [trackIDs objectAtIndex:i];
    rep     = [tracks objectForKey:trackID];
    track   = [[iTunesTrack alloc] initWithLibraryRepresentation:rep];
    [self->trackMap setObject:track forKey:trackID];
    [track release];
  }
  
  NSMutableDictionary *idPlMap;
  playlists = [lib objectForKey:@"Playlists"];
  count     = [playlists count];
  idPlMap   = [[NSMutableDictionary alloc] initWithCapacity:count];

  for (i = 0; i < count; i++) {
    NSDictionary   *plRep;
    iTunesPlaylist *pl;
    NSString       *plId;
  
    plRep = [playlists objectAtIndex:i];
    pl    = [[iTunesPlaylist alloc] initWithLibraryRepresentation:plRep
                                    lib:self];

    // only record top-level playlist, if playlist isn't a folder itself
    if (![pl parentId]) {
      [self->plMap setObject:pl
                   forKey:[self burnFolderNameFromFolderName:[pl name]]];
    }

    plId = [pl persistentId];
    if (plId)
      [idPlMap setObject:pl forKey:plId];
    [pl release];
  }

  // connect children to their parents
  if ([idPlMap count]) {
    NSArray *ids;
    
    ids   = [idPlMap allKeys];
    count = [ids count];
    for (i = 0; i < count; i++) {
      NSString       *plId;
      iTunesPlaylist *pl;
      NSString       *parentId;

      plId     = [ids objectAtIndex:i];
      pl       = [idPlMap objectForKey:plId];
      parentId = [pl parentId];
      if (parentId) {
        iTunesPlaylist *parent;
        
        parent = [idPlMap objectForKey:parentId];
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
  [idPlMap release];

  [self reloadVirtualMaps];
}

- (void)reloadVirtualMaps {
  if (!useCategories) return;

  [self->virtMap removeObjectForKey:kPlaylists];
  [self->virtMap removeObjectForKey:kSongs];

  if ([self->plMap count] == 1) {
    [self->virtMap setObject:[[self->plMap allValues] lastObject]
                   forKey:kSongs];
  }
  else {
    [self->virtMap setObject:self->plMap forKey:kPlaylists];
  }

  NSString *fmt = [[NSUserDefaults standardUserDefaults]
                                   stringForKey:@"AlbumsTrackFormat"];
  iTunesFSFormatter *formatter = [[iTunesFSFormatter alloc]
                                                     initWithFormatString:fmt];

  NSMutableDictionary *albums, *artists, *compilations;
  albums       = [self->virtMap objectForKey:kAlbums];
  artists      = [self->virtMap objectForKey:kArtists];
  compilations = [self->virtMap objectForKey:kCompilations];

  [albums       removeAllObjects];
  [artists      removeAllObjects];
  [compilations removeAllObjects];

  NSArray *tracks = [self->trackMap allValues];
  unsigned count  = [tracks count];
  for (unsigned i = 0; i < count; i++) {
    iTunesTrack *track;
    NSString            *artist, *album;
    NSString            *formattedArtist, *formattedAlbum, *formattedName;
    NSMutableDictionary *artistAlbums, *albumTracks;

    track  = [tracks objectAtIndex:i];
    artist = [track artist];
    if (!artist) artist = kUnknown;
    album  = [track album];
    if (!album)  album  = kUnknown;

    formattedArtist = [self burnFolderNameFromFolderName:artist];
    formattedAlbum  = [self burnFolderNameFromFolderName:album];
    artistAlbums    = [artists objectForKey:formattedArtist];
    if (!artistAlbums) {
      artistAlbums = [[NSMutableDictionary alloc] initWithCapacity:2];
      [artists setObject:artistAlbums forKey:formattedArtist];
      [artistAlbums release];
    }
    albumTracks = [artistAlbums objectForKey:formattedAlbum];
    if (!albumTracks) {
      albumTracks = [[NSMutableDictionary alloc] initWithCapacity:10];
      [artistAlbums setObject:albumTracks forKey:formattedAlbum];
      [albumTracks release];
    }
    formattedName = [formatter stringValueByFormattingObject:track];
    [albumTracks setObject:track forKey:formattedName];

    // now, for albums only
    albumTracks = [albums objectForKey:formattedAlbum];
    if (!albumTracks) {
      albumTracks = [[NSMutableDictionary alloc] initWithCapacity:10];
      [albums setObject:albumTracks forKey:formattedAlbum];
      [albumTracks release];
    }
    formattedName = [formatter stringValueByFormattingObject:track];
    [albumTracks setObject:track forKey:formattedName];
  }

  [formatter release];

  NSArray *allAlbums;

  allAlbums = [albums allValues];
  count     = [allAlbums count];
  for (unsigned i = 0; i < count; i++) {
    NSMutableDictionary *thisAlbum;
    NSString            *artist, *album;

    thisAlbum = [allAlbums objectAtIndex:i];
    tracks    = [thisAlbum allValues];

    artist = [[tracks objectAtIndex:0] artist];
    if (!artist) artist = kUnknown;
    album = [[tracks objectAtIndex:0] album];
    if (album) {
      unsigned tCount, j;

      tCount = [tracks count];
      if (tCount > 1) {
        NSString *formattedAlbum = [self burnFolderNameFromFolderName:album];
        for (j = 1; j < tCount; j++) {
          iTunesTrack *track;
          NSString    *tArtist;

          track   = [tracks objectAtIndex:j];
          tArtist = [track artist];
          if (!tArtist) tArtist = kUnknown;
          if (![artist isEqualToString:tArtist]) { 
            [compilations setObject:thisAlbum forKey:formattedAlbum];
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
    NSArray *allAlbums;

    allAlbums = [artists allValues];
    count     = [allAlbums count];
    for (unsigned i = 0; i < count; i++) {
      NSMutableDictionary *artistAlbums;
      unsigned            aCount, k;

      artistAlbums = [allAlbums objectAtIndex:i];
      aCount       = [artistAlbums count];
      if (aCount > 1) {
        NSArray             *allArtistAlbums;
        NSMutableDictionary *allTracks;

        allTracks = [[NSMutableDictionary alloc] initWithCapacity:10 * aCount];
        [artistAlbums setObject:allTracks forKey:kAll];
        [allTracks release];

        allArtistAlbums = [artistAlbums allValues];
        for (k = 0; k < aCount; k++) {
          NSDictionary *albumTracks;

          albumTracks = [allArtistAlbums objectAtIndex:k];
          /* NOTE:
           * This doesn't avoid collisions!!
           * It's unsuitable for COPYING content, though browsing does work
           * to some extent...
           */
          [allTracks addEntriesFromDictionary:albumTracks];
        }
      }
    }
  }
  
}

- (void)close {
  if (doDebug)
    NSLog(@"closing library: %@", self);

  [[Watchdog sharedWatchdog] forgetLibrary:self];
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
  return [self->plMap allKeys];
}
- (iTunesPlaylist *)playlistNamed:(NSString *)_plName {
  return [self->plMap objectForKey:_plName];
}


- (iTunesTrack *)trackWithID:(NSString *)_trackID {
  return [self->trackMap objectForKey:_trackID];
}

/* FUSEOFS */

- (id)lookupPathComponent:(NSString *)_pc inContext:(id)_ctx {
  if (!useCategories) {
    unsigned count = [self->plMap count];
    if (count == 0) return nil; // no playlists, no entries
    if (count == 1) {
      // hide single playlist altogether (i.e. iPod shuffle)
      return [[[self->plMap allValues] lastObject] lookupPathComponent:_pc
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
    return [[[self->plMap allValues] lastObject] containerContents];
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
  return [NSString stringWithFormat:@"<%@ 0x%x: name:%@ path:%@>",
                                    NSStringFromClass(self->isa), self,
                                    [self name], [self libraryPath]];
}

@end /* iTunesLibrary */
