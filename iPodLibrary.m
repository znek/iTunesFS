/*
  Copyright (c) 2007-2008, Marcus Müller <znek@mulle-kybernetik.com>.
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
#import "iPodLibrary.h"
#import <AppKit/AppKit.h>
#import "NSString+Extensions.h"
#import "iTunesPlaylist.h"
#import "iTunesTrack.h"

@interface iPodLibrary (Private)
- (NSString *)selectorNameForCode:(unsigned long)_code;
- (void)parseITunesDBAtPath:(NSString *)_path
  playlists:(NSArray **)_playlists
  tracks:(NSDictionary **)_tracks;
- (NSString *)iTunesDeviceInfoPath;
- (NSString *)iTunesMusicFolderPath;

- (NSDate *)dateFromMacTimestamp:(NSNumber *)_timestamp;

- (void)setFileLength:(id)_value;
- (void)setTrackNumber:(id)_value;
- (void)setDateAdded:(NSNumber *)_timestamp;
- (void)setDateModified:(NSNumber *)_timestamp;
@end

/* NOTE:
 * The following structures are taken from an old version of
 * Mulle PodLifter (ca. 2003, never publicly released).
 * The code works for my iPods (1G iPod, 1G shuffle, 5G nano) but might
 * fail for others.
 *
 * Information on iTunesDB can be found at:
 * http://ipodlinux.org/ITunesDB
 */

typedef struct {
  unsigned char pad[2];  // No NULL term!!
  unsigned char code[2]; // No NULL term!!
  unsigned long jump;
  unsigned long myLen;
  unsigned long count;
} fsbbStruct;

typedef struct {
  unsigned long  uniqueID;
  unsigned long  visible;
  unsigned long  fileType;
  unsigned short type;
  unsigned char  isCompilation;
  unsigned char  rating;
  unsigned long  dateModified;
  unsigned long  size;
  unsigned long  length;
  unsigned long  trackNumber;
  unsigned long  totalTracks;
  unsigned long  year;
  unsigned long  bitrate;
  unsigned long  sampleRate;
  unsigned long  volume;
  unsigned long  startTime;
  unsigned long  stopTime;
  unsigned long  soundcheck;
  unsigned long  playCount;
  unsigned long  playCountBackup;
  unsigned long  dateLastPlayed;
  unsigned long  discNumber;
  unsigned long  totalDiscs;
  unsigned long  userID;
  unsigned long  dateAdded;
} mhitExtra;

typedef struct {
  unsigned long res1;
  unsigned long strlength;
  unsigned long res2[2];
} stringParam;

typedef struct {
  unsigned long item_id;
  unsigned long res1[3];
} propertyParam;

typedef struct {
  unsigned long res1[2];
  unsigned long item_ref;
  unsigned short res2[2];
} playlistParam;

#define ULongNum(ul) [NSNumber numberWithUnsignedLong:(ul)]

@implementation iPodLibrary

static BOOL                doDebug     = NO;
static NSMutableDictionary *codeSelMap = nil;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  
  if (didInit) return;
  didInit       = YES;
  ud            = [NSUserDefaults standardUserDefaults];
  doDebug       = [ud boolForKey:@"iPodLibraryDebugEnabled"];

  codeSelMap = [[NSMutableDictionary alloc] initWithCapacity:4];
  [codeSelMap setObject:@"setName:"     forKey:[NSNumber numberWithInt:1]];
  [codeSelMap setObject:@"setLocation:" forKey:[NSNumber numberWithInt:2]];
  [codeSelMap setObject:@"setAlbum:"    forKey:[NSNumber numberWithInt:3]];
  [codeSelMap setObject:@"setArtist:"   forKey:[NSNumber numberWithInt:4]];
#if 0
  [codeSelMap setObject:@"setGenre:"    forKey:[NSNumber numberWithInt:5]];
  [codeSelMap setObject:@"setFiletype:" forKey:[NSNumber numberWithInt:6]];
  [codeSelMap setObject:@"setComment:"  forKey:[NSNumber numberWithInt:8]];
  [codeSelMap setObject:@"setComposer:" forKey:[NSNumber numberWithInt:12]];
#endif
}

+ (BOOL)isIPodAtMountPoint:(NSString *)_path {
  NSString *testPath;
  
  /* simple heuristic - works from 1G up to 5G iPods */
  testPath = [NSString stringWithFormat:@"%@/iPod_Control", _path];
  return [[NSFileManager defaultManager] fileExistsAtPath:testPath];
}

- (id)initWithMountPoint:(NSString *)_path {
  self->mountPoint = [_path copy];
  [self init];
  return self;
}

- (void)dealloc {
  [self->mountPoint release];
  [super dealloc];
}

/* setup */

- (void)reload {
  NSArray      *playlists;
  NSDictionary *tracks;
  NSArray      *trackIDs;
  unsigned     i, count;

  [self parseITunesDBAtPath:[self libraryPath]
        playlists:&playlists
        tracks:&tracks];
  
  [self->plMap    removeAllObjects];
  [self->trackMap removeAllObjects];
  
  trackIDs  = [tracks allKeys];
  count     = [trackIDs count];
  for (i = 0; i < count; i++) {
    NSString     *trackID;
    NSDictionary *rep;
    iTunesTrack  *track;
    
    trackID = [trackIDs objectAtIndex:i];
    rep     = [tracks objectForKey:trackID];
    track   = [[iTunesTrack alloc] initWithIPodLibraryRepresentation:rep];
    [self->trackMap setObject:track forKey:trackID];
    [track release];
  }
  
  count     = [playlists count];
  for (i = 0; i < count; i++) {
    NSDictionary   *plRep;
    iTunesPlaylist *pl;
    
    plRep = [playlists objectAtIndex:i];
    pl    = [[iTunesPlaylist alloc] initWithIPodLibraryRepresentation:plRep
                                    lib:self];
    [self->plMap setObject:pl
                 forKey:[self burnFolderNameFromFolderName:[pl name]]];
    [pl release];
  }
  [self reloadVirtualMaps];
}

/* private */

- (NSString *)selectorNameForCode:(unsigned long)_code {
  return [codeSelMap objectForKey:ULongNum(_code)];
}

- (void)parseITunesDBAtPath:(NSString *)_path
  playlists:(NSArray **)_playlists
  tracks:(NSDictionary **)_tracks
{
  NSFileHandle        *fh;
  NSDictionary        *fileAttrs;
  unsigned long       fileLength;
  unsigned long       filePos;
  NSData              *data;
  NSMutableArray      *playlists; 
  NSMutableDictionary *tmap;
  
  playlists  = nil;
  tmap       = nil;
  fileAttrs  = [[NSFileManager defaultManager]
                               fileAttributesAtPath:_path traverseLink:YES];
  NSAssert1(fileAttrs != nil, @"Cannot open iTunesDB at path '%@'", _path);
  fileLength = [[fileAttrs objectForKey:NSFileSize] unsignedLongValue];
  fh         = [NSFileHandle fileHandleForReadingAtPath:_path];
  filePos    = 0;
  
  while(filePos < fileLength) {
    fsbbStruct *fsbb;
    
    data        = [fh readDataOfLength:sizeof(fsbbStruct)];
    fsbb        = (fsbbStruct *)[data bytes];
    fsbb->jump  = NSSwapLittleLongToHost(fsbb->jump);
    fsbb->myLen = NSSwapLittleLongToHost(fsbb->myLen);
    fsbb->count = NSSwapLittleLongToHost(fsbb->count);
    
    if (memcmp(fsbb->code, "bd", 2) == 0) { // begin of database
      if (doDebug) NSLog(@"%.8x Beginning of database\n", filePos);
    }
    else if(memcmp(fsbb->code, "sd", 2) == 0) { // a list type header
      if (fsbb->count != 1 && fsbb->count != 2) {
        if (doDebug) {
          NSLog(@"WARN: %.8x UNKNOWN %c%c %ld %ld %ld\n",
                filePos, fsbb->code[0], fsbb->code[1],
                fsbb->jump, fsbb->myLen, fsbb->count);
        }
      }
    }
    else if (memcmp(fsbb->code, "lt", 2) == 0) { // list of tracks
      if (doDebug) NSLog(@"%.8x %ld-item list:\n", filePos, fsbb->myLen);
      if (!tmap) {
        tmap = [[NSMutableDictionary alloc] initWithCapacity:fsbb->myLen];
      }
    }
    else if (memcmp(fsbb->code, "lp", 2) == 0) { // list of playlists
      if (doDebug) NSLog(@"%.8x %ld-item list:\n", filePos, fsbb->myLen);

      if (!playlists)
        playlists = [[NSMutableArray alloc] initWithCapacity:fsbb->myLen];
    }
    else if (memcmp(fsbb->code, "yp", 2) == 0) { // a playlist
      NSMutableArray *trackIDs;

      if (doDebug) NSLog(@"%.8x playlist:\n", filePos);

      trackIDs            = [[NSMutableArray alloc]      initWithCapacity:12];
      self->currentObject = [[NSMutableDictionary alloc] initWithCapacity:1];
      [self->currentObject setObject:trackIDs forKey:@"trackIDs"];
      [trackIDs release];
      [playlists addObject:self->currentObject];
      [self->currentObject release];
    }
    else if (memcmp(fsbb->code, "ip", 2) == 0) { // a playlist item
      NSMutableDictionary *track;
      playlistParam       *playlist;
      NSString            *trackID;

      data               = [fh readDataOfLength:16];
      playlist           = (playlistParam *)[data bytes];
      playlist->item_ref = NSSwapLittleLongToHost(playlist->item_ref);
      trackID            = [ULongNum(playlist->item_ref) description];
      track              = [tmap objectForKey:trackID];
      if (!track && doDebug) {
        NSLog(@"ERR: Referenced unknown track with id '%ld'",
              playlist->item_ref);
      }
      else {
        NSMutableArray *trackIDs;
        
        trackIDs = [self->currentObject objectForKey:@"trackIDs"];
        [trackIDs addObject:trackID];
      }
      if (doDebug)
        NSLog(@"%.8x itemref (%ld): %@\n", filePos, playlist->item_ref, track);
    }
    else if(memcmp(fsbb->code, "it", 2) == 0) { // a track item
      mhitExtra *prop;
      NSString  *trackID;

      data               = [fh readDataOfLength:sizeof(mhitExtra)];
      prop               = (mhitExtra *)[data bytes];
      prop->uniqueID     = NSSwapLittleLongToHost(prop->uniqueID);
      prop->size         = NSSwapLittleLongToHost(prop->size);
      prop->trackNumber  = NSSwapLittleLongToHost(prop->trackNumber);
      prop->dateModified = NSSwapLittleLongToHost(prop->dateModified);
      prop->dateAdded    = NSSwapLittleLongToHost(prop->dateAdded);
      trackID            = [ULongNum(prop->uniqueID) description];

      self->currentObject = [[NSMutableDictionary alloc] initWithCapacity:2];
      [tmap setObject:self->currentObject forKey:trackID];

      [self setFileLength:ULongNum(prop->size)];
      [self setTrackNumber:ULongNum(prop->trackNumber)];
      [self setDateAdded:ULongNum(prop->dateAdded)];
      [self setDateModified:ULongNum(prop->dateModified)];

      [self->currentObject release];

      if (doDebug) {
        NSLog(@"%.8x %ld-property item (%ld):\n",
              filePos, fsbb->count, prop->uniqueID);
      }
    }
    else if (memcmp(fsbb->code, "od", 2) == 0) { // unicode string
      stringParam *sp;
      
      if (doDebug) {
        NSLog(@"%.8x Unicode String(%c%c) %ld %ld %ld\t",
              filePos, fsbb->code[0], fsbb->code[1], fsbb->jump,
              fsbb->myLen, fsbb->count);
      }
      // skip 8 bytes, because jump is always 24
      [fh seekToFileOffset:filePos + 24];
      data          = [fh readDataOfLength:16];
      sp            = (stringParam *)[data bytes];
      sp->strlength = NSSwapLittleLongToHost(sp->strlength);

      if (fsbb->myLen == 0) // Bad something, skip outta here
        continue;

      if ((sp->strlength != 0) &&
          ([self selectorNameForCode:fsbb->count] != nil))
      {
        NSString *selectorName, *value;
        
        data         = [fh readDataOfLength:sp->strlength];
        selectorName = [self selectorNameForCode:fsbb->count];
        if (selectorName) {
          SEL selector;

          selector = NSSelectorFromString(selectorName);
          value    = [[NSString alloc] initWithLittleEndianUnicodeData:data];
          [self performSelector:selector withObject:value];
        }
      }
      fsbb->jump = fsbb->myLen;
    }
    else { // unknown code
      if (doDebug) {
        NSLog(@"%.8x %c%c %ld %ld %ld\n",
              filePos, fsbb->code[0], fsbb->code[1], fsbb->jump,
              fsbb->myLen, fsbb->count);
      }
    }
    
    filePos += fsbb->jump;
    [fh seekToFileOffset:filePos];
  }
  
  // clean-up
  [fh closeFile];
  self->currentObject = nil;
  *_tracks            = [tmap  autorelease];
  *_playlists         = [playlists autorelease];
}

- (NSString *)iTunesDeviceInfoPath {
  return [NSString stringWithFormat:@"%@/iPod_Control/iTunes/DeviceInfo",
                                    self->mountPoint];
}

- (NSString *)iTunesMusicFolderPath {
  return [NSString stringWithFormat:@"%@/iPod_Control/Music/",
                                    self->mountPoint];
}

/* iTunesDB code / selectors */

- (void)setName:(NSString *)_value {
  [self->currentObject setValue:_value forKey:@"name"];
}

- (void)setLocation:(NSString *)_value {
  NSArray  *pc;
  unsigned count;
  NSString *path;
  NSURL    *url;

  pc    = [_value componentsSeparatedByString:@":"];
  count = [pc count];
  if (count < 2) {
    NSLog(@"%s -- illegal value for location, got '%@'",
          __PRETTY_FUNCTION__, _value);
    return;
  }
  pc   = [pc subarrayWithRange:NSMakeRange(count - 2, 2)];
  path = [NSString pathWithComponents:pc];
  path = [[self iTunesMusicFolderPath] stringByAppendingPathComponent:path];
  url  = [NSURL fileURLWithPath:path];
  [self->currentObject setValue:url forKey:@"location"];
}

- (void)setAlbum:(NSString *)_value {
  [self->currentObject setValue:_value forKey:@"Album"];
}

- (void)setArtist:(NSString *)_value {
  [self->currentObject setValue:_value forKey:@"Artist"];
}

- (void)setFileLength:(id)_value {
  [self->currentObject setValue:_value forKey:@"Size"];
}

- (void)setTrackNumber:(id)_value {
  [self->currentObject setValue:_value forKey:@"Track Number"];
}

#define macTimeOffset 2082844800
- (NSDate *)dateFromMacTimestamp:(NSNumber *)_timestamp {
  NSTimeInterval t;
  
  t = (NSTimeInterval)([_timestamp unsignedLongValue] - macTimeOffset);
  return [NSDate dateWithTimeIntervalSince1970:t];
}
#undef macTimeOffset

- (void)setDateAdded:(NSNumber *)_timestamp {
  [self->currentObject setValue:[self dateFromMacTimestamp:_timestamp]
                       forKey:@"Date Added"];
}

- (void)setDateModified:(NSNumber *)_timestamp {
  [self->currentObject setValue:[self dateFromMacTimestamp:_timestamp]
                       forKey:@"Date Modified"];
}

/* accessors */

- (NSString *)name {
  if (!self->name) {
    NSString *devInfoPath;
    NSData   *devInfo, *leData;
    NSString *devName;
    ushort   nameLen;

    devInfoPath = [self iTunesDeviceInfoPath];
    if (devInfoPath &&
        (devInfo = [NSData dataWithContentsOfFile:devInfoPath]))
    {
      [devInfo getBytes:&nameLen length:sizeof(nameLen)];
      nameLen    = NSSwapLittleShortToHost(nameLen);
      leData     = [devInfo subdataWithRange:NSMakeRange(sizeof(nameLen),
                                                         nameLen * 2)];
      devName    = [[NSString alloc] initWithLittleEndianUnicodeData:leData];
      self->name = [[devName properlyEscapedFSRepresentation] copy];
      [devName release];
    }
    else {
      self->name = [[self->mountPoint lastPathComponent] copy];
    }
  }
  return self->name;
}

- (NSString *)libraryPath {
  return [NSString stringWithFormat:@"%@/iPod_Control/iTunes/iTunesDB",
                                    self->mountPoint];
}

- (NSString *)mountPoint {
  return self->mountPoint;
}

- (NSImage *)icon {
  return [[NSWorkspace sharedWorkspace] iconForFile:self->mountPoint];
}

@end /* iPodLibrary */
