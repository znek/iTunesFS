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
#import "IFSiPodLibrary.h"
#import "FUSEOFSMemoryContainer.h"
#import <AppKit/AppKit.h>
#import "NSString+Extensions.h"
#import "NSObject+FUSEOFS.h"
#import "IFSiTunesPlaylist.h"
#import "IFSiTunesTrack.h"
#import "NSData+ZlibDecompression.h"
#import "StreamReader.h"
#ifndef GNU_GUI_LIBRARY
#import "NSImage+IconData.h"
#endif

#if __LP64__ || NS_BUILD_32_LIKE_64
  typedef unsigned int ITDBUInt32;
  typedef unsigned long ITDBUInt64;
#else
  typedef unsigned long ITDBUInt32;
  typedef unsigned long long ITDBUInt64;
#endif

@interface IFSiPodLibrary (Private)
- (NSString *)selectorNameForCode:(ITDBUInt32)_code;
- (void)parseITunesDBAtPath:(NSString *)_path
  playlists:(NSArray **)_playlists
  tracks:(NSDictionary **)_tracks;
- (NSString *)iTunesDeviceInfoPath;
- (NSString *)iTunesMusicFolderPath;

- (NSDate *)dateFromMacTimestamp:(NSNumber *)_timestamp;

- (void)setFileLength:(id)_value;
- (void)setTrackNumber:(id)_value;

- (void)setRating:(id)_value;
- (void)setDiscNumber:(id)_value;
- (void)setDiscCount:(id)_value;
- (void)setPlayCount:(id)_value;
- (void)setYear:(id)_value;
- (void)setBitRate:(id)_value;
- (void)setSampleRate:(id)_value;
- (void)setSeasonNumber:(id)_value;
- (void)setEpisodeNumber:(id)_value;

- (void)setDateAdded:(NSNumber *)_timestamp;
- (void)setDateModified:(NSNumber *)_timestamp;
- (void)setDateReleased:(NSNumber *)_timestamp;
- (void)setDateLastPlayed:(NSNumber *)_timestamp;

@end

/* NOTE:
 * The following structures are taken from an old version of
 * Mulle PodLifter (ca. 2003, never publicly released).
 * The code works for my iPods (1G iPod, 1G shuffle, 5G nano) but might
 * fail for others.
 *
 * Information on iTunesDB can be found at:
 * http://ipodlinux.org/wiki/ITunesDB
 * - OR -
 * http://ipl.derpapst.eu/wiki/ITunesDB
 */

typedef struct {
  unsigned char pad[2];  // No NULL term!!
  unsigned char code[2]; // No NULL term!!
  ITDBUInt32 jump;
  ITDBUInt32 myLen;
  ITDBUInt32 count;
} fsbbStruct;

typedef struct {
  ITDBUInt32 uniqueID;
  ITDBUInt32 visible;
  ITDBUInt32 fileType;
  unsigned short type;
  unsigned char  isCompilation;
  unsigned char  rating;
  ITDBUInt32 dateModified;
  ITDBUInt32 size;
  ITDBUInt32 length;
  ITDBUInt32 trackNumber;
  ITDBUInt32 totalTracks;
  ITDBUInt32 year;
  ITDBUInt32 bitRate;
  ITDBUInt32 sampleRate;
  ITDBUInt32 volume;
  ITDBUInt32 startTime;
  ITDBUInt32 stopTime;
  ITDBUInt32 soundcheck;
  ITDBUInt32 playCount;
  ITDBUInt32 playCountBackup;
  ITDBUInt32 dateLastPlayed;
  ITDBUInt32 discNumber;
  ITDBUInt32 totalDiscs;
  ITDBUInt32 userID;
  ITDBUInt32 dateAdded;
  ITDBUInt32 bookmarkTime;
  ITDBUInt64 dbid;
  unsigned char isChecked;
  unsigned char applicationRating;
  unsigned short bpm;
  unsigned short artworkCount;
  unsigned short unk9;
  ITDBUInt32 artworkSize;
  ITDBUInt32 unk11;
  ITDBUInt32 sampleRate2;
  ITDBUInt32 dateReleased;
  unsigned short unk14_1;
  unsigned short explicitFlag;
  ITDBUInt32 unk15;
  ITDBUInt32 unk16;
  ITDBUInt32 skipCount;
  ITDBUInt32 lastSkipped;
  unsigned char hasArtwork; // 0x02 for tracks without artwork
  unsigned char skipWhenShuffling;
  unsigned char rememberPlaybackPosition;
  unsigned char flag4;
  ITDBUInt64 dbid2;
  unsigned char hasLyrics;
  unsigned char isMovieFile;
  unsigned char isPlayed; // 0x02 not played, 0x01 played
  unsigned char unk17;
  ITDBUInt32 unk21;
  ITDBUInt32 pregap;
  ITDBUInt64 sampleCount;
  ITDBUInt32 unk25;
  ITDBUInt32 postgap;
  ITDBUInt32 unk27;
  ITDBUInt32 mediaType; // 0 audio/video, 1 audio, 2 video, 4 podcast, 6 video podcast, 8 audiobook, 0x20 music video, 0x40 tv show, 0x60 tv show
  ITDBUInt32 seasonNumber;
  ITDBUInt32 episodeNumber;
  ITDBUInt32 unk31;
  ITDBUInt32 unk32;
  ITDBUInt32 unk33;
  ITDBUInt32 unk34;
  ITDBUInt32 unk35;
  ITDBUInt32 unk36;
  ITDBUInt32 unk37;
  ITDBUInt32 gaplessData;
  ITDBUInt32 unk38;
  unsigned short gaplessTrackFlag; // 0x0001 has gapless playback data
  unsigned short gaplessAlbumFlag; // 0x0001 no crossfading
  unsigned char  unk39[20]; // hash?
  ITDBUInt32 unk40;
  ITDBUInt32 unk41;
  ITDBUInt32 unk42;
  ITDBUInt32 unk43;
  unsigned short unk44;
  unsigned short albumID;
  ITDBUInt32 mhiiLink;
  ITDBUInt32 artistID;
} mhitExtra;

typedef struct {
  ITDBUInt32 itemCount;
  unsigned char isMasterPlaylist;
  unsigned char unk[3];
  ITDBUInt32 dateCreated;
  ITDBUInt64 persistentID;
  ITDBUInt32 unk3;
  unsigned short stringMhodsCount;
  unsigned char isPodcastPlaylist;
  unsigned char isGroup;
  ITDBUInt32 sortOrderField;
} mhypExtra;

typedef struct {
  ITDBUInt32 res1;
  ITDBUInt32 strlength;
  ITDBUInt32 res2[2];
} stringParam;

typedef struct {
  ITDBUInt32 item_id;
  ITDBUInt32 res1[3];
} propertyParam;

typedef struct {
  ITDBUInt32 res1[2];
  ITDBUInt32 item_ref;
  unsigned short res2[2];
} playlistParam;

#define ULongNum(ul) [NSNumber numberWithUnsignedLong:(ul)]
#define ULongLongNum(ull) [NSNumber numberWithUnsignedLongLong:(ull)]

@implementation IFSiPodLibrary

static BOOL doDebug        = NO;
static BOOL debugIsVerbose = NO;
static NSMutableDictionary *codeSelMap = nil;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  
  if (didInit) return;
  didInit        = YES;
  ud             = [NSUserDefaults standardUserDefaults];
  doDebug        = [ud boolForKey:@"IFSiPodLibraryDebugEnabled"];
  debugIsVerbose = [ud boolForKey:@"IFSiPodLibraryDebugVerbose"];

  codeSelMap = [[NSMutableDictionary alloc] initWithCapacity:4];
  [codeSelMap setObject:@"setName:"        forKey:[NSNumber numberWithInt:1]];
  [codeSelMap setObject:@"setLocation:"    forKey:[NSNumber numberWithInt:2]];
  [codeSelMap setObject:@"setAlbum:"       forKey:[NSNumber numberWithInt:3]];
  [codeSelMap setObject:@"setArtist:"      forKey:[NSNumber numberWithInt:4]];
  [codeSelMap setObject:@"setGenre:"       forKey:[NSNumber numberWithInt:5]];
  [codeSelMap setObject:@"setComposer:"    forKey:[NSNumber numberWithInt:12]];
  [codeSelMap setObject:@"setGrouping:"    forKey:[NSNumber numberWithInt:13]];
  [codeSelMap setObject:@"setSeries:"      forKey:[NSNumber numberWithInt:19]];
  [codeSelMap setObject:@"setAlbumArtist:" forKey:[NSNumber numberWithInt:22]];
#if 0
  [codeSelMap setObject:@"setFiletype:"    forKey:[NSNumber numberWithInt:6]];
  [codeSelMap setObject:@"setComment:"     forKey:[NSNumber numberWithInt:8]];
#endif
}

+ (NSString *)iTunesControlPathComponent {
  return @"iPod_Control";
}

+ (BOOL)isIPodAtMountPoint:(NSString *)_path {
  NSString *testPath;
  
  /* simple heuristic - works from 1G up to 5G iPods */
  testPath = [NSString stringWithFormat:@"%@/%@",
                                        _path,
                                        [self iTunesControlPathComponent]];
  return [[NSFileManager defaultManager] fileExistsAtPath:testPath];
}

- (id)initWithMountPoint:(NSString *)_path {
  self->mountPoint = [_path copy];
  [self init];
  return self;
}

- (void)dealloc {
  [self close];
  [self->mountPoint release];
  self->mountPoint = nil;
  [super dealloc];
}

/* setup */

- (void)reload {
  NSArray      *playlists;
  NSDictionary *tracks;
  NSArray      *trackIDs;
  NSUInteger   i, count;

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
    IFSiTunesTrack  *track;
    
    trackID = [trackIDs objectAtIndex:i];
    rep     = [tracks objectForKey:trackID];
    track   = [[IFSiTunesTrack alloc] initWithLibraryRepresentation:rep];
    if ([track url])
      [self->trackMap setObject:track forKey:trackID];
    [track release];
  }

  count     = [playlists count];
  for (i = 0; i < count; i++) {
    NSDictionary   *plRep;
    IFSiTunesPlaylist *pl;
    
    plRep = [playlists objectAtIndex:i];
    pl    = [[IFSiTunesPlaylist alloc] initWithLibraryRepresentation:plRep
                                    lib:self];
    [self->plMap setItem:pl
                 forName:[self burnFolderNameFromFolderName:[pl name]]];
    [pl release];
  }
  [self reloadVirtualMaps];
}

- (void)close {
	if (self->mountPoint)
		[super close];
}

/* private */

- (NSString *)selectorNameForCode:(ITDBUInt32)_code {
  return [codeSelMap objectForKey:ULongNum(_code)];
}

- (void)parseITunesDBAtPath:(NSString *)_path
  playlists:(NSArray **)_playlists
  tracks:(NSDictionary **)_tracks
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDictionary  *fileAttrs;
  
#if MAC_OS_X_VERSION_10_6 <= MAC_OS_X_VERSION_MAX_ALLOWED
  fileAttrs = [fm attributesOfItemAtPath:_path error:NULL];
#else
  fileAttrs = [fm fileAttributesAtPath:_path traverseLink:YES];
#endif

  NSAssert1(fileAttrs != nil, @"Cannot open iTunesDB at path '%@'", _path);

  unsigned long fileLength = [[fileAttrs objectForKey:NSFileSize]
                                         unsignedLongValue];
  unsigned long filePos    = 0;
  NSFileHandle  *fh        = [NSFileHandle fileHandleForReadingAtPath:_path];
  StreamReader  *sr        = [[StreamReader alloc] initWithFileHandle:fh];

  NSMutableArray      *playlists = nil;
  NSMutableDictionary *tmap      = nil;

  while (filePos < fileLength) {
    NSData     *data = [sr readDataOfLength:sizeof(fsbbStruct)];
    fsbbStruct *fsbb = (fsbbStruct *)[data bytes];
    fsbb->jump  = NSSwapLittleIntToHost(fsbb->jump);
    fsbb->myLen = NSSwapLittleIntToHost(fsbb->myLen);
    fsbb->count = NSSwapLittleIntToHost(fsbb->count);

    if (memcmp(fsbb->code, "bd", 2) == 0) { // begin of database
      if (doDebug && debugIsVerbose)
        NSLog(@"[0x%08lx] Beginning of database", filePos);

      // compressed database?
      if (fsbb->count == 2) {
        if (doDebug && debugIsVerbose)
          NSLog(@"[0x%08lx] database might be compressed", filePos);
        ITDBUInt32 version;
        data = [sr readDataOfLength:sizeof(ITDBUInt32)];
        version = *(ITDBUInt32 *)[data bytes];
        version = NSSwapLittleIntToHost(version);
        
        // compressed!
        if (version >= 0x28) {
          if (doDebug && debugIsVerbose) {
            NSLog(@"[0x%08lx] database is compressed (version: 0x%lu), "
                  "decompressing", filePos, (unsigned long)version);
          }

          // read compressed stream into data
          filePos += fsbb->jump;
          [sr seekToOffset:filePos];
          data = [sr readDataOfLength:fsbb->myLen];
          [sr release];

          // decompress data and create new stream for reading this data
          data       = [data decompressedDataUsingZlib];
          sr         = [[StreamReader alloc] initWithData:data];
          fileLength = [data length];
          filePos    = 0;
          fsbb->jump = 0;
        }
      }
    }
    else if (memcmp(fsbb->code, "sd", 2) == 0) { // a list type header
      if (fsbb->count != 1 && fsbb->count != 2) {
        if (doDebug) {
          NSLog(@"WARN: [0x%08lx] unknown list type header '%lu', "
                "jump:0x%lu length:0x%lu",
                filePos, (unsigned long)fsbb->count,
                (unsigned long)fsbb->jump, (unsigned long)fsbb->myLen);
        }
      }
    }
    else if (memcmp(fsbb->code, "lt", 2) == 0) { // list of tracks
      if (doDebug && debugIsVerbose)
        NSLog(@"[0x%08lx] %ld-item list:", filePos, (unsigned long)fsbb->myLen);
      if (!tmap) {
        tmap = [[NSMutableDictionary alloc] initWithCapacity:fsbb->myLen];
      }
    }
    else if (memcmp(fsbb->code, "lp", 2) == 0) { // list of playlists
      if (doDebug && debugIsVerbose)
        NSLog(@"[0x%08lx] %lu-item list:", filePos, (unsigned long)fsbb->myLen);

      if (!playlists)
        playlists = [[NSMutableArray alloc] initWithCapacity:fsbb->myLen];
    }
    else if (memcmp(fsbb->code, "yp", 2) == 0) { // a playlist
      if (doDebug && debugIsVerbose)
        NSLog(@"[0x%08lx] playlist:", filePos);

      data = [sr readDataOfLength:sizeof(mhypExtra)];
      mhypExtra *prop = (mhypExtra *)[data bytes];
      prop->persistentID = NSSwapLittleLongLongToHost(prop->persistentID);
      NSString *persistentID = [NSString stringWithFormat:@"%llX",
                                         (unsigned long long)prop->persistentID];

      self->currentObject = [[NSMutableDictionary alloc] initWithCapacity:2];
      [self->currentObject setObject:persistentID forKey:kPlaylistPersistentID];

      NSMutableArray *trackIDs = [[NSMutableArray alloc] initWithCapacity:12];
      [self->currentObject setObject:trackIDs forKey:@"trackIDs"];
      [trackIDs release];
      [playlists addObject:self->currentObject];
      [self->currentObject release];
    }
    else if (memcmp(fsbb->code, "ip", 2) == 0) { // a playlist item
      NSMutableDictionary *track;
      playlistParam       *playlist;
      NSString            *trackID;

      data               = [sr readDataOfLength:16];
      playlist           = (playlistParam *)[data bytes];
      playlist->item_ref = NSSwapLittleIntToHost(playlist->item_ref);
      trackID            = [ULongNum(playlist->item_ref) description];
      track              = [tmap objectForKey:trackID];
      if (!track && doDebug) {
        NSLog(@"ERROR: [0x%08lx] referenced unknown track with id '%ld'",
              filePos, (long)playlist->item_ref);
      }
      else {
        NSMutableArray *trackIDs;
        
        trackIDs = [self->currentObject objectForKey:@"trackIDs"];
        [trackIDs addObject:trackID];
      }
      if (doDebug && debugIsVerbose) {
        NSLog(@"[0x%08lx] itemref (%ld): %@",
              filePos, (long)playlist->item_ref, track);
      }
    }
    else if (memcmp(fsbb->code, "it", 2) == 0) { // a track item
      data = [sr readDataOfLength:sizeof(mhitExtra)];
      mhitExtra *prop = (mhitExtra *)[data bytes];

      prop->uniqueID       = NSSwapLittleIntToHost(prop->uniqueID);
      prop->size           = NSSwapLittleIntToHost(prop->size);
      prop->trackNumber    = NSSwapLittleIntToHost(prop->trackNumber);
      prop->dateModified   = NSSwapLittleIntToHost(prop->dateModified);
      prop->dateAdded      = NSSwapLittleIntToHost(prop->dateAdded);
      prop->dateLastPlayed = NSSwapLittleIntToHost(prop->dateLastPlayed);
      prop->dateReleased   = NSSwapLittleIntToHost(prop->dateReleased);
      prop->discNumber     = NSSwapLittleIntToHost(prop->discNumber);
      prop->totalDiscs     = NSSwapLittleIntToHost(prop->totalDiscs);
      prop->playCount      = NSSwapLittleIntToHost(prop->playCount);
      prop->year           = NSSwapLittleIntToHost(prop->year);
      prop->bitRate        = NSSwapLittleIntToHost(prop->bitRate);
      prop->sampleRate     = NSSwapLittleIntToHost(prop->sampleRate);
      prop->seasonNumber   = NSSwapLittleIntToHost(prop->seasonNumber);
      prop->episodeNumber  = NSSwapLittleIntToHost(prop->episodeNumber);

      NSString *trackID = [ULongNum(prop->uniqueID) description];

      self->currentObject = [[NSMutableDictionary alloc] initWithCapacity:2];
      [tmap setObject:self->currentObject forKey:trackID];

      [self setFileLength:ULongNum(prop->size)];
      [self setTrackNumber:ULongNum(prop->trackNumber)];
      [self setDateAdded:ULongNum(prop->dateAdded)];
      [self setDateModified:ULongNum(prop->dateModified)];
      [self setDateLastPlayed:ULongNum(prop->dateLastPlayed)];
      [self setRating:[NSNumber numberWithChar:prop->rating]];
      [self setDiscNumber:ULongNum(prop->discNumber)];
      [self setDiscCount:ULongNum(prop->totalDiscs)];
      [self setPlayCount:ULongNum(prop->playCount)];
      [self setYear:ULongNum(prop->year)];
      [self setBitRate:ULongNum(prop->bitRate)];
      [self setSampleRate:ULongNum(prop->sampleRate / 0x10000)];
      [self setSeasonNumber:ULongNum(prop->seasonNumber)];
      [self setEpisodeNumber:ULongNum(prop->episodeNumber)];
#if 0
      [self setDateReleased:ULongNum(prop->dateReleased)];
#endif

      [self->currentObject release];

      if (doDebug && debugIsVerbose) {
        NSLog(@"[0x%08lx] %ld-property item (%ld):",
              filePos, (long)fsbb->count, (long)prop->uniqueID);
      }
    }
    else if (memcmp(fsbb->code, "od", 2) == 0) { // unicode string
      stringParam *sp;
      
      if (doDebug && debugIsVerbose) {
        NSLog(@"[0x%08lx] unicode string '%c%c'",
              filePos, fsbb->code[0], fsbb->code[1]);
      }
      // skip 8 bytes, because jump is always 24
      [sr seekToOffset:filePos + 24];
      data          = [sr readDataOfLength:16];
      sp            = (stringParam *)[data bytes];
      sp->strlength = NSSwapLittleIntToHost(sp->strlength);

      if (fsbb->myLen == 0) // Bad something, skip outta here
        continue;

      if ((sp->strlength != 0) &&
          ([self selectorNameForCode:fsbb->count] != nil))
      {
        data = [sr readDataOfLength:sp->strlength];
        NSString *selectorName = [self selectorNameForCode:fsbb->count];
        if (selectorName) {
          SEL      selector = NSSelectorFromString(selectorName);
          NSString *value   = [[NSString alloc]
                                         initWithLittleEndianUnicodeData:data];
          [self performSelector:selector withObject:value];
        }
      }
      fsbb->jump = fsbb->myLen;
    }
    else { // unknown code
      if (doDebug) {
        NSLog(@"WARN: [0x%08lx] unknown code '%c%c', "
              "jump:0x%lu length:0x%lu count:0x%lu",
              filePos, fsbb->code[0], fsbb->code[1],
              (unsigned long)fsbb->jump, (unsigned long)fsbb->myLen,
              (unsigned long)fsbb->count);
      }
    }
    
    filePos += fsbb->jump;
    [sr seekToOffset:filePos];
  }
  
  // clean-up
  [sr release];
  self->currentObject = nil;
  *_tracks            = [tmap  autorelease];
  *_playlists         = [playlists autorelease];
}

- (NSString *)iTunesDeviceInfoPath {
  return [NSString stringWithFormat:@"%@/%@/iTunes/DeviceInfo",
                                    self->mountPoint,
                                    [[self class] iTunesControlPathComponent]];
}

- (NSString *)iTunesMusicFolderPath {
  return [NSString stringWithFormat:@"%@/%@/Music/",
                                    self->mountPoint,
                                    [[self class] iTunesControlPathComponent]];

}

/* iTunesDB code / selectors */

- (void)setName:(NSString *)_value {
  [self->currentObject setValue:_value forKey:kTrackName];
}

- (void)setLocation:(NSString *)_value {
  NSArray *pc = [_value componentsSeparatedByString:@":"];
  NSUInteger count = [pc count];
  if (count < 2) {
    NSLog(@"%s -- illegal value for location, got '%@'",
          __PRETTY_FUNCTION__, _value);
    return;
  }
  pc   = [pc subarrayWithRange:NSMakeRange(count - 2, 2)];
  NSString *path = [NSString pathWithComponents:pc];
  path = [[self iTunesMusicFolderPath] stringByAppendingPathComponent:path];
  NSURL *url = [NSURL fileURLWithPath:path];
  [self->currentObject setValue:[url description] forKey:kTrackLocation];
}

- (void)setAlbum:(NSString *)_value {
  [self->currentObject setValue:_value forKey:kTrackAlbum];
}
- (void)setArtist:(NSString *)_value {
  [self->currentObject setValue:_value forKey:kTrackArtist];
}
- (void)setAlbumArtist:(NSString *)_value {
  [self->currentObject setValue:_value forKey:kTrackAlbumArtist];
}
- (void)setGenre:(NSString *)_value {
  [self->currentObject setValue:_value forKey:kTrackGenre];
}
- (void)setComposer:(NSString *)_value {
  [self->currentObject setValue:_value forKey:kTrackComposer];
}
- (void)setGrouping:(NSString *)_value {
  [self->currentObject setValue:_value forKey:kTrackGrouping];
}
- (void)setSeries:(NSString *)_value {
  [self->currentObject setValue:_value forKey:kTrackSeries];
}
- (void)setFileLength:(id)_value {
  [self->currentObject setValue:_value forKey:kTrackSize];
}
- (void)setTrackNumber:(id)_value {
  [self->currentObject setValue:_value forKey:kTrackNumber];
}
- (void)setRating:(id)_value {
  [self->currentObject setValue:_value forKey:kTrackRating];
}
- (void)setDiscNumber:(id)_value {
  [self->currentObject setValue:_value forKey:kTrackDiscNumber];
}
- (void)setDiscCount:(id)_value {
  [self->currentObject setValue:_value forKey:kTrackDiscCount];
}
- (void)setPlayCount:(id)_value {
  [self->currentObject setValue:_value forKey:kTrackPlayCount];
}
- (void)setYear:(id)_value {
  [self->currentObject setValue:_value forKey:kTrackYear];
}
- (void)setBitRate:(id)_value {
  [self->currentObject setValue:_value forKey:kTrackBitRate];
}
- (void)setSampleRate:(id)_value {
  [self->currentObject setValue:_value forKey:kTrackSampleRate];
}
- (void)setSeasonNumber:(id)_value {
  [self->currentObject setValue:_value forKey:kTrackSeasonNumber];
}
- (void)setEpisodeNumber:(id)_value {
  [self->currentObject setValue:_value forKey:kTrackEpisodeNumber];
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
                       forKey:kTrackDateAdded];
}
- (void)setDateModified:(NSNumber *)_timestamp {
  [self->currentObject setValue:[self dateFromMacTimestamp:_timestamp]
                       forKey:kTrackDateModified];
}
- (void)setDateReleased:(NSNumber *)_timestamp {
  [self->currentObject setValue:[self dateFromMacTimestamp:_timestamp]
                       forKey:kTrackDateReleased];
}
- (void)setDateLastPlayed:(NSNumber *)_timestamp {
  [self->currentObject setValue:[self dateFromMacTimestamp:_timestamp]
                       forKey:kTrackPlayDateUTC];
}

/* accessors */

- (NSString *)name {
  if (!self->name) {
    NSString *devInfoPath;
    NSData   *devInfo, *leData;
    NSString *devName;
    uint16_t nameLen;

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
  NSString *path = [NSString stringWithFormat:@"%@/%@/iTunes/iTunesCDB",
                                              [self mountPoint],
                                              [[self class]
                                                     iTunesControlPathComponent]];
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:path])
    return path;
  return [NSString stringWithFormat:@"%@/%@/iTunes/iTunesDB",
                                    [self mountPoint],
                                    [[self class] iTunesControlPathComponent]];
}

- (NSString *)mountPoint {
  return self->mountPoint;
}

/* FUSEOFS */

- (NSData *)iconData {
  NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:self->mountPoint];
#ifndef GNU_GUI_LIBRARY
  return [icon icnsDataWithWidth:512];
#else
  return [icon TIFFRepresentation];
#endif
}

@end /* IFSiPodLibrary */
