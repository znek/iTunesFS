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
#import "iTunesPlaylist.h"
#import "iTunesLibrary.h"
#import "iTunesTrack.h"
#import "iTunesFSFormatter.h"
#import "NSObject+FUSEOFS.h"
#import "FUSEOFSMemoryContainer.h"
#import "iTunesFormatFile.h"

@interface iTunesPlaylist (Private)
- (BOOL)hasTrackFormatFile;
- (BOOL)showTrackFormatFile;
- (NSString *)trackFormatFileName;
- (void)generatePrettyTrackNames;
- (void)setName:(NSString *)_name;
- (void)addTrack:(iTunesTrack *)_track withName:(NSString *)_name;
@end

@implementation iTunesPlaylist

static BOOL doDebug = NO;
static BOOL showPersistentID    = NO;
static BOOL showTrackFormatFile = YES;
static NSString *trackFormatFileName = @"PlaylistsTrackFormat.txt";

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  
  if (didInit) return;
  didInit  = YES;
  ud       = [NSUserDefaults standardUserDefaults];
  doDebug  = [ud boolForKey:@"iTunesFileSystemDebugEnabled"];
  showPersistentID    = [ud boolForKey:@"ShowPersistentIDs"];
  showTrackFormatFile = [ud boolForKey:@"ShowFormatFiles"];
}

- (id)init {
  self = [super init];
  if (self) {
    self->savedTracks  = [[NSMutableArray alloc] initWithCapacity:10];
    self->tracks       = [[NSMutableArray alloc] initWithCapacity:10];
    self->trackNames   = [[NSMutableArray alloc] initWithCapacity:10];
    self->childrenMap  = [[NSMutableDictionary alloc] initWithCapacity:5];
    // NOTE: cannot initialize trackFormatFile here, needs lazy init
    self->shadowFolder = [[FUSEOFSMemoryContainer alloc] init];
    self->modificationDate = [[NSDate date] retain];
  }
  return self;
}

- (id)initWithLibraryRepresentation:(NSDictionary *)_list
  lib:(iTunesLibrary *)_lib
{
  self = [self init];
  if (self) {
    BOOL isFolder;

    self->persistentId = [[_list objectForKey:kPlaylistPersistentID] copy];
    self->parentId     = [[_list objectForKey:kPlaylistParentPersistentID] copy];
    [self setName:[_list objectForKey:kPlaylistName]];

    isFolder = [[_list objectForKey:kPlaylistIsFolder] boolValue];

    if (!isFolder) {
      BOOL itemIsDictionary = YES;
      NSArray *items = [_list objectForKey:kPlaylistItems];
      if (!items) {
        items = [_list objectForKey:kPlaylistTrackIDs];
        itemIsDictionary = NO;
      }

      unsigned i, count = [items count];
      for (i = 0; i < count; i++) {
        id item = [items objectAtIndex:i];
        NSString *trackID;
        if (itemIsDictionary)
          trackID = [[item objectForKey:kTrackID] description];
        else
          trackID = (NSString *)item;

        iTunesTrack *trk = [_lib trackWithID:trackID];
        if (!trk) {
          /* NOTE: Rolf's library really sports these effects, seems to be
           * limited to Podcasts only.
           */
          if (doDebug)
            NSLog(@"Playlist[%@]: found no track item for #%@",
                  self->name, trackID);
          continue;
        }
        [self->savedTracks addObject:trk];
      }
      [self generatePrettyTrackNames];
    }
  }
  return self;
}

- (void)dealloc {
  [self->persistentId release];
  [self->parentId     release];
  [self->name         release];
  [self->savedTracks  release];
  [self->tracks       release];
  [self->trackNames   release];
  [self->childrenMap  release];
  [self->shadowFolder release];
  [self->trackFormatFile  release];
  [self->modificationDate release];
  [super dealloc];
}

/* private */

- (BOOL)hasTrackFormatFile {
  return self->persistentId != nil && self->trackFormatFile;
}
- (BOOL)showTrackFormatFile {
  if (![self hasTrackFormatFile])
    return NO;
  return showTrackFormatFile;
}

- (void)generatePrettyTrackNames {
  if (!self->trackFormatFile) {
    self->trackFormatFile = [[iTunesFormatFile alloc]
                               initWithDefaultTemplate:@"PlaylistsTrackFormat"
                               templateId:self->persistentId];
  }
  [self->tracks     removeAllObjects];
  [self->trackNames removeAllObjects];

  [self->modificationDate release];
  self->modificationDate = [[NSDate date] retain];

  NSArray *childrenKeys = [self->childrenMap allKeys];
  unsigned i, count     = [childrenKeys count];
  for (i = 0; i < count; i++) {
    NSString       *childKey = [childrenKeys objectAtIndex:i];
    iTunesPlaylist *child    = [self->childrenMap objectForKey:childKey];
    if (![child persistentId]) {
      // remove virtual child
      [self->childrenMap removeObjectForKey:childKey];
    }
  }
  
  iTunesFSFormatter *formatter = [self->trackFormatFile getFormatter];
  if ([formatter isPathFormat]) {

    // formatter describes a path, which can lead to a whole hierarchy
    // of virtual playlists.
    // for every track in this current playlist we need to traverse its
    // formatter path and possibly create and add any virtual playlists
    // necessary in that process.

    unsigned i, count = [self->savedTracks count];
    for (i = 0; i < count; i++) {
      iTunesTrack *trk     = [self->savedTracks objectAtIndex:i];
      unsigned    trkIndex = i + 1;
      [trk setPlaylistNumber:trkIndex];
      NSArray *pathComponents = [formatter
                                   pathComponentsByFormattingObject:trk];
      iTunesPlaylist *pl = self;
      NSString *pc;
      unsigned k, pcCount = [pathComponents count];
      for (k = 0; k < (pcCount - 1); k++) {
        pc = [pathComponents objectAtIndex:k];
        iTunesPlaylist *nextPl = [pl lookupPathComponent:pc inContext:nil];
        if (!nextPl || ![nextPl isContainer]) {
          nextPl = [[iTunesPlaylist alloc] init];
          [nextPl setName:pc];
          [pl addChild:nextPl withName:pc];
          [nextPl release];
        }
        pl = nextPl;
      }
      [pl addTrack:trk withName:[pathComponents objectAtIndex:k]];
    }
  }
  else {
    unsigned i, count  = [self->savedTracks count];
    for (i = 0; i < count; i++) {
      iTunesTrack *trk     = [self->savedTracks objectAtIndex:i];
      unsigned    trkIndex = i + 1;
      [trk setPlaylistNumber:trkIndex];
      NSString *tn = [formatter stringValueByFormattingObject:trk];
      [self addTrack:trk withName:tn];
    }
  }
}

/* accessors */

- (void)setName:(NSString *)_name {
  _name = [[_name properlyEscapedFSRepresentation] copy];
  [self->name release];
  self->name = _name;
}
- (NSString *)name {
  if (!showPersistentID || !self->persistentId)
    return self->name;
  return [NSString stringWithFormat:@"%@[%@]", self->name, self->persistentId];
}

- (NSString *)persistentId {
  return self->persistentId;
}
- (NSString *)parentId {
  return self->parentId;
}

- (void)addTrack:(iTunesTrack *)_track withName:(NSString *)_name {
  [self->tracks addObject:_track];
  [self->trackNames addObject:_name];
}

- (NSArray *)tracks {
  return self->tracks;
}

- (unsigned)count {
  return [self->tracks count];
}

- (iTunesTrack *)trackAtIndex:(unsigned)_idx {
  return [self->tracks objectAtIndex:_idx];
}

- (NSArray *)trackNames {
  return self->trackNames;
}

- (void)addChild:(iTunesPlaylist *)_child withName:(NSString *)_name {
  [self->childrenMap setObject:_child
                     forKey:[_name properlyEscapedFSRepresentation]];
}

/* FUSEOFS */

- (id)lookupPathComponent:(NSString *)_pc inContext:(id)_ctx {
  if ([_pc isEqualToString:trackFormatFileName] &&
      [self hasTrackFormatFile])
  {
    return self->trackFormatFile;
  }

  id result = [self->childrenMap objectForKey:_pc];
  if (result)
    return result;

  NSUInteger idx = [[self trackNames] indexOfObject:_pc];
  if (idx != NSNotFound)
    result = [self trackAtIndex:idx];
  if (!result && [self hasTrackFormatFile])
    result = [self->shadowFolder lookupPathComponent:_pc inContext:_ctx];
  return result;
}

- (NSArray *)containerContents {
  if (![self showTrackFormatFile]) {
    // in this case, we can possibly eliminate an unnecessary copy
    if ([self->childrenMap count] && ![[self trackNames] count])
      return [self->childrenMap allKeys];
    else if (![self->childrenMap count] && [[self trackNames] count])
      return [self trackNames];
  }

  NSMutableArray *names = [[NSMutableArray alloc]
                                           initWithArray:self->trackNames];
  [names addObjectsFromArray:[self->childrenMap allKeys]];
  if ([self showTrackFormatFile]) {
    [names addObject:trackFormatFileName];
#if 0
    [names addObjectsFromArray:[self->shadowFolder containerContents]];
#endif
  }
  return [names autorelease];
}

- (BOOL)isContainer {
  return YES;
}
- (BOOL)isMutable {
  return YES;
}

#if 0

// NOTE: in theory this should do the trick of hiding the .fpbf extension,
// however this flag has been removed from Finder.h altogether and it doesn't
// work in practice (tested on 10.5.6)

- (NSDictionary *)finderAttributes {
		NSNumber *finderFlags = [NSNumber numberWithLong:0x0010];
		return [NSDictionary dictionaryWithObject:finderFlags
                         forKey:kGMUserFileSystemFinderFlagsKey];
}
#endif

- (NSDictionary *)fileAttributes {
  NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithCapacity:5];
  [attrs setObject:self->modificationDate forKey:NSFileCreationDate];
  [attrs setObject:self->modificationDate forKey:NSFileModificationDate];
  [attrs setObject:NSFileTypeDirectory forKey:NSFileType];
  [attrs setObject:[NSNumber numberWithBool:YES] forKey:NSFileExtensionHidden];
  NSNumber *perm = [NSNumber numberWithInt:[self isMutable] ? 0777 : 0555];
  [attrs setObject:perm forKey:NSFilePosixPermissions];
  return attrs;
}

#if 0
- (BOOL)createFileNamed:(NSString *)_name
  withAttributes:(NSDictionary *)_attrs
{
  if (![self hasTrackFormatFile])
    return NO;
  if (![_name isEqualTo:trackFormatFileName])
    return NO;

  return YES;
}
#endif

- (BOOL)createContainerNamed:(NSString *)_name
  withAttributes:(NSDictionary *)_attrs
{
  return [self->shadowFolder createContainerNamed:_name withAttributes:_attrs];
}

- (BOOL)writeFileNamed:(NSString *)_name withData:(NSData *)_data {
  if (![self hasTrackFormatFile])
    return NO;
  if (![_name isEqualToString:trackFormatFileName])
    return [self->shadowFolder writeFileNamed:_name withData:_data];

  [self->trackFormatFile setFileContents:_data];
  [self generatePrettyTrackNames];
  return YES;
}

- (BOOL)removeItemNamed:(NSString *)_name {
  if (![self hasTrackFormatFile])
    return NO;

  if ([_name isEqualToString:trackFormatFileName]) {
    [self->trackFormatFile remove];
    [self generatePrettyTrackNames];
    return YES;
  }
  return [self->shadowFolder removeItemNamed:_name];
}


/* debugging */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%s 0x%x: name:%@ #tracks:%d>",
                                    object_getClassName(self), self,
                                    [self name], [self count]];
}

@end /* iTunesPlaylist */
