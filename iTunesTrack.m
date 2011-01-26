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
#import "iTunesTrack.h"
#import "NSURL+Extensions.h"
#import "NSObject+FUSEOFS.h"

@interface iTunesTrack (Private)
- (NSString *)prettyName;
- (void)setPrettyName:(NSString *)_prettyName;
- (void)setUrl:(NSURL *)_url;
- (NSURL *)url;
- (void)setAttributes:(NSDictionary *)_attributes;
- (NSDictionary *)attributes;
- (void)setTrackNumber:(unsigned)_trackNumber;
@end

@implementation iTunesTrack

static BOOL     doDebug                    = NO;
static BOOL     useSymbolicLinks           = NO;
static NSString *locationReplacePrefix     = nil;
static NSString *locationDestinationPrefix = nil;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  
  if (didInit) return;
  didInit                   = YES;
  ud                        = [NSUserDefaults standardUserDefaults];
  doDebug                   = [ud boolForKey:@"iTunesFileSystemDebugEnabled"];
  useSymbolicLinks          = [ud boolForKey:@"SymbolicLinks"];
  locationReplacePrefix     = [ud stringForKey:@"LocationReplacePrefix"];
  locationDestinationPrefix = [ud stringForKey:@"LocationDestinationPrefix"];

  if (doDebug && useSymbolicLinks)
    NSLog(@"Using symbolic links for tracks");
}

/* init & dealloc */

- (id)initWithITunesLibraryRepresentation:(NSDictionary *)_track {
  self = [super init];
  if (self) {
    NSString            *name;
    NSNumber            *tn;
    NSString            *location;
    NSMutableDictionary *attrs;
    id                  tmp;

    self->artist = [[[_track objectForKey:@"Artist"]
                             properlyEscapedFSRepresentation] copy];
    self->album  = [[[_track objectForKey:@"Album"]
                             properlyEscapedFSRepresentation] copy];

    tn = [_track objectForKey:@"Track Number"];
    [self setTrackNumber:[tn unsignedIntValue]];

    name = [_track objectForKey:@"Name"];
    if (name) {
      [self setPrettyName:[name properlyEscapedFSRepresentation]];
    }
    else {
      NSLog(@"WARN: track without name! REP:%@", _track);
      [self setPrettyName:@"Empty"];
    }
    location = [_track objectForKey:@"Location"];
    if (location) {
      if ([location hasPrefix:@"file"]) {
        self->ext = [[location pathExtension] copy];
      }
      else {
        /* http:// stream address... */
        self->ext = @"webloc";
      }
      if (locationReplacePrefix) {
        NSRange r;
        
        r = [location rangeOfString:locationReplacePrefix];
        if (r.location != NSNotFound) {
          location = [location substringFromIndex:NSMaxRange(r)];
          location = [locationDestinationPrefix
                                              stringByAppendingString:location];
        }
      }
      [self setUrl:[NSURL URLWithString:location]];
    }

    attrs = [[NSMutableDictionary alloc] initWithCapacity:3];
    if ([[self url] isFileURL]) {
      tmp = [_track objectForKey:@"Size"];
      if (tmp)
        [attrs setObject:tmp forKey:NSFileSize];
    }
    tmp = [_track objectForKey:@"Date Added"];
    if (tmp)
      [attrs setObject:tmp forKey:NSFileCreationDate];
    tmp = [_track objectForKey:@"Date Modified"];
    if (tmp) {
      [attrs setObject:tmp forKey:NSFileModificationDate];
    }
    else {
      tmp = [_track objectForKey:@"Play Date UTC"];
      if (tmp)
        [attrs setObject:tmp forKey:NSFileModificationDate];
    }
    if (useSymbolicLinks)
      [attrs setObject:NSFileTypeSymbolicLink forKey:NSFileType];
	else
	  [attrs setObject:NSFileTypeRegular forKey:NSFileType];

    [self setAttributes:attrs];
    [attrs release];
  }
  return self;
}

- (id)initWithIPodLibraryRepresentation:(NSDictionary *)_track {
  self = [super init];
  if (self) {
    NSString            *name;
    NSNumber            *tn;
    NSURL               *location;
    NSMutableDictionary *attrs;
    id                  tmp;

    self->artist = [[[_track objectForKey:@"Artist"]
                             properlyEscapedFSRepresentation] copy];
    self->album  = [[[_track objectForKey:@"Album"]
                             properlyEscapedFSRepresentation] copy];

    tn = [_track objectForKey:@"Track Number"];
    [self setTrackNumber:[tn unsignedIntValue]];

    name = [_track objectForKey:@"name"];
    if (name) {
      [self setPrettyName:[name properlyEscapedFSRepresentation]];
    }
    else {
      NSLog(@"WARN: track without name! REP:%@", _track);
      [self setPrettyName:@"Empty"];
    }
    location = [_track objectForKey:@"location"];
    if (location) {
      if ([location isFileURL]) {
        self->ext = [[[location path] pathExtension] copy];
      }
      else {
        self->ext = @"webloc";
      }
      [self setUrl:location];
    }

    attrs = [[NSMutableDictionary alloc] initWithCapacity:3];
    if ([[self url] isFileURL]) {
      tmp = [_track objectForKey:@"Size"];
      if (tmp)
        [attrs setObject:tmp forKey:NSFileSize];
    }
    tmp = [_track objectForKey:@"Date Added"];
    if (tmp)
      [attrs setObject:tmp forKey:NSFileCreationDate];
    tmp = [_track objectForKey:@"Date Modified"];
    if (tmp)
      [attrs setObject:tmp forKey:NSFileModificationDate];
    if (useSymbolicLinks)
      [attrs setObject:NSFileTypeSymbolicLink forKey:NSFileType];

    [self setAttributes:attrs];
    [attrs release];
  }
  return self;
}

- (void)dealloc {
  [self->prettyName release];
  [self->album      release];
  [self->artist     release];
  [self->url        release];
  [self->attributes release];
  [self->ext        release];
  [super dealloc];
}

/* accessors */

- (void)setPrettyName:(NSString *)_prettyName {
  _prettyName = [_prettyName copy];
  [self->prettyName release];
  self->prettyName = _prettyName;
}
- (NSString *)prettyName {
  return self->prettyName;
}
- (NSString *)name {
  return self->prettyName;
}

- (NSString *)album {
  return self->album;
}
- (NSString *)artist {
  return self->artist;
}

- (void)setUrl:(NSURL *)_url {
  _url = [_url copy];
  [self->url release];
  self->url = _url;
}
- (NSURL *)url {
  return self->url;
}
- (NSString *)extension {
  return self->ext;
}
- (NSString *)ext {
  if (self->ext)
    return self->ext;
  return @"m4a";
}

- (void)setAttributes:(NSDictionary *)_attributes {
  _attributes = [_attributes copy];
  [self->attributes release];
  self->attributes = _attributes;
}
- (NSDictionary *)attributes {
  return self->attributes;
}

- (void)setTrackNumber:(unsigned)_trackNumber {
  self->trackNumber = _trackNumber;
}
- (unsigned)trackNumber {
  return self->trackNumber;
}

- (void)setPlaylistNumber:(unsigned)_playlistNumber {
  self->playlistNumber = _playlistNumber;
}
- (unsigned)playlistNumber {
  return self->playlistNumber;
}


/* FUSEOFS */

- (NSDictionary *)fileAttributes {
  return [self attributes];
}

- (NSData *)fileContents {
  NSString *path;

  if (!self->url) return nil;
  if (![self->url isFileURL]) { /* http based audio stream... */
    return [[self->url description] dataUsingEncoding:NSUTF8StringEncoding];
  }
  path = [self->url properlyEscapedPath];
  return [NSData dataWithContentsOfFile:path
                 options:NSUncachedRead
                 error:NULL];
}

- (NSDictionary *)resourceAttributes {
  if ([self->url isFileURL]) return nil;
  return [NSDictionary dictionaryWithObject:self->url
                       forKey:kGMUserFileSystemWeblocURLKey];
}

- (NSString *)symbolicLinkTarget {
  return [self->url properlyEscapedPath];
}

/* debugging */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ 0x%x: name:%@ attrs:%@>",
                                    NSStringFromClass(self->isa), self,
                                    [self prettyName], [self attributes]];
}

@end /* iTunesTrack */
