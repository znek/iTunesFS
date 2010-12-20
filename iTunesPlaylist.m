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
#import "NSString+Extensions.h"
#import "iTunesFSFormatter.h"
#import "NSObject+FUSEOFS.h"
#import "FUSEOFSMemoryFolder.h"
#import "FUSEOFSFileProxy.h"

@interface iTunesPlaylist (Private)
- (BOOL)hasTrackFormatFile;
- (BOOL)showsTrackFormatFile;
- (NSString *)trackFormatFileName;
- (NSString *)trackFormatDefaultKey;
- (NSString *)trackFormatDefaultKeyForID:(NSString *)_id;

- (NSString *)getTrackFormatString;
- (iTunesFSFormatter *)getTrackFormatter;

- (void)generatePrettyTrackNames;
- (void)setName:(NSString *)_name;
- (void)addTrack:(iTunesTrack *)_track withName:(NSString *)_name;
@end

@implementation iTunesPlaylist

static BOOL doDebug = NO;
static BOOL showPersistentID = NO;
static iTunesFSFormatter *plTrackFormatter = nil;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  NSString       *fmt;
  
  if (didInit) return;
  didInit          = YES;
  ud               = [NSUserDefaults standardUserDefaults];
  doDebug          = [ud boolForKey:@"iTunesFileSystemDebugEnabled"];
  showPersistentID = [ud boolForKey:@"ShowPersistentIDs"];
  fmt              = [ud stringForKey:@"PlaylistsTrackFormat"];
  plTrackFormatter = [[iTunesFSFormatter alloc] initWithFormatString:fmt];
  
  if (doDebug)
    NSLog(@"PlaylistsTrackFormat: %@", fmt);
}

- (id)init {
  self = [super init];
  if (self) {
    self->savedTracks  = [[NSMutableArray alloc] initWithCapacity:10];
    self->tracks       = [[NSMutableArray alloc] initWithCapacity:10];
    self->trackNames   = [[NSMutableArray alloc] initWithCapacity:10];
    self->childrenMap  = [[NSMutableDictionary alloc] initWithCapacity:5];
#if 0
    self->shadowFolder = [[FUSEOFSMemoryFolder alloc] init];
#else
    self->shadowFolder = [[FUSEOFSFileProxy alloc] initWithPath:@"/tmp/xxx"];
#endif
  }
  return self;
}

- (id)initWithITunesLibraryRepresentation:(NSDictionary *)_list
  lib:(iTunesLibrary *)_lib
{
  self = [self init];
  if (self) {
    BOOL isFolder;

    self->persistentId = [[_list objectForKey:@"Playlist Persistent ID"] copy];
    self->parentId     = [[_list objectForKey:@"Parent Persistent ID"] copy];
    [self setName:[_list objectForKey:@"Name"]];

    isFolder = [[_list objectForKey:@"Folder"] boolValue];

    if (!isFolder) {
      NSArray  *items   = [_list objectForKey:@"Playlist Items"];
      unsigned i, count = [items count];

      for (i = 0; i < count; i++) {
        NSDictionary *item    = [items objectAtIndex:i];
        NSString     *trackID = [[item objectForKey:@"Track ID"] description];
        iTunesTrack  *trk     = [_lib trackWithID:trackID];
        if (!trk) {
          /* NOTE: Rolf's library really sports these effects, seems to be
           * limited to Podcasts only.
           */
          if (doDebug)
            NSLog(@"INFO Playlist[%@]: found no track item for #%@",
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

- (id)initWithIPodLibraryRepresentation:(NSDictionary *)_list
  lib:(iTunesLibrary *)_lib
{
  self = [self init];
  if (self) {
    [self setName:[_list objectForKey:@"name"]];

    NSArray  *items   = [_list objectForKey:@"trackIDs"];
    unsigned i, count = [items count];
    for (i = 0; i < count; i++) {
      NSString    *trackID = [items objectAtIndex:i];
      iTunesTrack *trk     = [_lib trackWithID:trackID];
      if (!trk) {
        /* NOTE: Rolf's library really sports these effects, seems to be
        * limited to Podcasts only.
        */
        if (doDebug)
          NSLog(@"INFO Playlist[%@]: found no track item for #%@",
                self->name, trackID);
        continue;
      }
      [self->savedTracks addObject:trk];
    }
    [self generatePrettyTrackNames];
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
  [super dealloc];
}

/* private */

- (BOOL)hasTrackFormatFile {
  return self->persistentId != nil;
}
- (BOOL)showsTrackFormatFile {
  if (![self hasTrackFormatFile])
    return NO;
  return YES;
}
- (NSString *)trackFormatFileName {
  return @"PlaylistsTrackFormat.txt";
}
- (NSString *)trackFormatDefaultKey {
  if (!self->persistentId) return nil;
  return [self trackFormatDefaultKeyForID:[self persistentId]];
}
- (NSString *)trackFormatDefaultKeyForID:(NSString *)_id {
  return [NSString stringWithFormat:@"PlaylistsTrackFormat[%@]", _id];
}

- (NSString *)getTrackFormatString {
  NSString *defKey = [self trackFormatDefaultKey];
  if (!defKey)
    return [plTrackFormatter formatString];

  NSString *fmt = [[NSUserDefaults standardUserDefaults] stringForKey:defKey];
  if (!fmt)
    fmt = [plTrackFormatter formatString];
  return fmt;
}

- (iTunesFSFormatter *)getTrackFormatter {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSString *fmtKey   = [self trackFormatDefaultKey];
  if (fmtKey) {
    NSString *fmt = [ud stringForKey:fmtKey];
    if (fmt) {
      // is it an alias?
      if ([fmt hasPrefix:@"@"] && ([fmt length] > 1)) {
        fmt = [fmt substringFromIndex:1];
        if (doDebug)
          NSLog(@"%@ is an alias to %@", fmtKey, fmt);
        fmtKey = [self trackFormatDefaultKeyForID:fmt];
        fmt    = [ud stringForKey:fmtKey];
      }
      if (fmt) {
        return [[[iTunesFSFormatter alloc] initWithFormatString:fmt]
                                           autorelease];
      }
      else {
        if (doDebug)
          NSLog(@"WARN: no format found for reference %@", fmtKey);
      }
    }
  }
  return plTrackFormatter;
}

- (void)generatePrettyTrackNames {
  [self->tracks     removeAllObjects];
  [self->trackNames removeAllObjects];

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
  
  iTunesFSFormatter *formatter = [self getTrackFormatter];
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
        if (!nextPl || ![nextPl isDirectory]) {
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
  if ([_pc isEqualToString:[self trackFormatFileName]] &&
      [self hasTrackFormatFile])
  {
    // TODO: this SHOULD be an own object!
    NSMutableString *format = [[NSMutableString alloc] initWithCapacity:300];
    [format appendString:@"# "];
    [format appendFormat:[self trackFormatDefaultKey]];
    [format appendString:@"\n"];
    [format appendString:[self getTrackFormatString]];
    [format appendString:@"\n"];
    return [format autorelease];
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

- (NSArray *)directoryContents {
  if (![self showsTrackFormatFile]) {
    // in this case, we can possibly eliminate an unnecessary copy
    if ([self->childrenMap count] && ![[self trackNames] count])
      return [self->childrenMap allKeys];
    else if (![self->childrenMap count] && [[self trackNames] count])
      return [self trackNames];
  }

  NSMutableArray *names = [[NSMutableArray alloc]
                                           initWithArray:self->trackNames];
  [names addObjectsFromArray:[self->childrenMap allKeys]];
  if ([self showsTrackFormatFile]) {
    [names addObject:[self trackFormatFileName]];
//    [names addObjectsFromArray:[self->shadowFolder directoryContents]];
  }
  return [names autorelease];
}

- (BOOL)isDirectory {
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

#if 0
- (BOOL)createFileNamed:(NSString *)_name
  withAttributes:(NSDictionary *)_attrs
{
  if (![self hasTrackFormatFile])
    return NO;
  if (![_name isEqualTo:[self trackFormatFileName]])
    return NO;

  return YES;
}
#endif

- (BOOL)createDirectoryNamed:(NSString *)_name
  withAttributes:(NSDictionary *)_attrs
{
  return [self->shadowFolder createDirectoryNamed:_name withAttributes:_attrs];
}

- (BOOL)writeFileNamed:(NSString *)_name withData:(NSData *)_data {
  if (![self hasTrackFormatFile])
    return NO;
  if (![_name isEqualToString:[self trackFormatFileName]])
    return [self->shadowFolder writeFileNamed:_name withData:_data];

  // NOTE: this is just a quick hack, but should be refactored to a more
  // robust implementation once we settle on this concept.

  NSCharacterSet *trimSet    = [NSCharacterSet
                                characterSetWithCharactersInString:@"\n\r\t "];
  NSString       *rawDefault = [[[NSString alloc] initWithData:_data
                                                  encoding:NSUTF8StringEncoding]
                                                  autorelease];
  rawDefault = [rawDefault stringByTrimmingCharactersInSet:trimSet];
  NSArray  *lines      = [rawDefault componentsSeparatedByString:@"\n"];
  NSString *newDefault = [lines lastObject];
  if (newDefault && [newDefault length]) {
    [[NSUserDefaults standardUserDefaults] setObject:newDefault
                                           forKey:[self trackFormatDefaultKey]];
  }
  else {
    [[NSUserDefaults standardUserDefaults]
                     removeObjectForKey:[self trackFormatDefaultKey]];
  }
  [self generatePrettyTrackNames];
  return YES;
}

- (BOOL)removeItemNamed:(NSString *)_name {
  if (![self hasTrackFormatFile])
    return NO;

  if ([_name isEqualToString:[self trackFormatFileName]]) {
    [[NSUserDefaults standardUserDefaults]
                     removeObjectForKey:[self trackFormatDefaultKey]];
    [self generatePrettyTrackNames];
    return YES;
  }
  return [self->shadowFolder removeItemNamed:_name];
}


/* debugging */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ 0x%x: name:%@ #tracks:%d>",
                                    NSStringFromClass(self->isa), self,
                                    [self name], [self count]];
}

@end /* iTunesPlaylist */
