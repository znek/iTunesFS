/*
  Copyright (c) 2007, Marcus Müller <znek@mulle-kybernetik.com>.
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

@interface iTunesLibrary (Private)
- (iTunesTrack *)trackWithPrettyName:(NSString *)_ptn
  inPlaylistNamed:(NSString *)_plName;
@end

@implementation iTunesLibrary

static NSString *libraryPath  = nil;
static NSImage  *libraryIcon  = nil;
static BOOL     detailedNames = NO;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  
  if (didInit) return;
  didInit     = YES;
  ud          = [NSUserDefaults standardUserDefaults];
  libraryPath = [[ud stringForKey:@"Library"] copy];
  if (!libraryPath) {
    libraryPath = [[NSHomeDirectory() stringByAppendingString:
                                      @"/Music/iTunes/iTunes Music Library.xml"]
                                      copy];
  }
  libraryIcon   = [[[NSWorkspace sharedWorkspace]
                                 iconForFile:@"/Applications/iTunes.app"]
                                 copy];
  detailedNames = [ud boolForKey:@"DetailedTrackNames"];
  [iTunesTrack setUseDetailedInformationInNames:detailedNames];
}

- (id)init {
  self = [super init];
  if (self) {
    self->plMap = [[NSMutableDictionary alloc] initWithCapacity:128];
    [self reload];
    [[Watchdog sharedWatchdog] watchLibrary:self];
  }
  return self;
}

- (void)dealloc {
  [[Watchdog sharedWatchdog] forgetLibrary:self];
  [self->plMap release];
  [super dealloc];
}

/* setup */

- (void)reload {
  NSData        *plist;
  NSDictionary  *lib;
  NSArray       *playlists;
  NSDictionary  *tracks;
  unsigned      i, count;

#if 0
  NSLog(@"%s", __PRETTY_FUNCTION__);
#endif

  [self->plMap removeAllObjects];
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

  playlists = [lib objectForKey:@"Playlists"];
  tracks    = [lib objectForKey:@"Tracks"];
  count     = [playlists count];
  for (i = 0; i < count; i++) {
    NSDictionary   *plRep;
    iTunesPlaylist *pl;

    plRep = [playlists objectAtIndex:i];
    pl    = [[iTunesPlaylist alloc] initWithITunesRepresentation:plRep
                                    tracks:tracks];
    [self->plMap setObject:pl forKey:[pl name]];
    [pl release];
  }
}

/* accessors */

- (NSString *)name {
  return self->name;
}

- (NSImage *)icon {
  return libraryIcon;
}

- (NSString *)libraryPath {
  return libraryPath;
}

- (NSArray *)playlistNames {
  return [self->plMap allKeys];
}

- (NSArray *)trackNamesForPlaylistNamed:(NSString *)_plName {
  return [[self->plMap objectForKey:_plName] trackNames];
}

- (BOOL)isValidTrackName:(NSString *)_ptn inPlaylistNamed:(NSString *)_plName {
#if 0
  if(![_ptn isValidTrackName]) {
    NSLog(@"NOT valid track name! -> %@", _ptn);
    return NO;
  }
  return YES;
#else
  return [_ptn isValidTrackName];
#endif
}

- (iTunesTrack *)trackWithPrettyName:(NSString *)_ptn
  inPlaylistNamed:(NSString *)_plName
{
  iTunesPlaylist *pl;
  unsigned       idx;
  
  pl = [self->plMap objectForKey:_plName];
  if (!pl) return nil;
  idx = [_ptn playlistIndex];
  return [pl trackAtIndex:idx];
}

- (NSData *)fileContentForTrackWithPrettyName:(NSString *)_ptn
  inPlaylistNamed:(NSString *)_plName
{
  return [[self trackWithPrettyName:_ptn inPlaylistNamed:_plName] fileContent];
}

- (NSDictionary *)fileAttributesForTrackWithPrettyName:(NSString *)_ptn
  inPlaylistNamed:(NSString *)_plName
{
  return [[self trackWithPrettyName:_ptn inPlaylistNamed:_plName]
                fileAttributes];
}

@end /* iTunesLibrary */
