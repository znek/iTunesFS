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
#import "iTunesTrack.h"
#import "NSString+Extensions.h"

@interface iTunesTrack (Private)
- (void)setName:(NSString *)_name;
- (void)setUrl:(NSURL *)_url;
- (NSURL *)url;
@end

@implementation iTunesTrack

static BOOL detailedNames = NO;

+ (void)setUseDetailedInformationInNames:(BOOL)_yn {
  detailedNames = _yn;
}

/* init & dealloc */

- (id)initWithITunesRepresentation:(NSDictionary *)_track
  playlistIndex:(unsigned)_idx;
{
  self = [super init];
  if (self) {
    NSString        *artist, *album;
    NSNumber        *trackNumber;
    NSString        *location;
    NSMutableString *prettyName;

    prettyName = [[NSMutableString alloc] initWithCapacity:128];
    [prettyName appendFormat:@"%03d ", _idx + 1];
    
    if (detailedNames) {
      artist = [_track objectForKey:@"Artist"];
      if (artist) {
        [prettyName appendString:[artist properlyEscapedFSRepresentation]];
        [prettyName appendString:@"_"];
      }
      album = [_track objectForKey:@"Album"];
      if (album) {
        [prettyName appendString:[album properlyEscapedFSRepresentation]];
        [prettyName appendString:@"_"];
      }
      trackNumber = [_track objectForKey:@"Track Number"];
      if (trackNumber) {
        [prettyName appendString:[trackNumber description]];
        [prettyName appendString:@" "];
      }
    }
    [prettyName appendString:[[_track objectForKey:@"Name"]
                                      properlyEscapedFSRepresentation]];
#if 0
    [prettyName appendString:@" ["];
    [prettyName appendString:_trackID];
    [prettyName appendString:@"]"];
#endif
    location = [_track objectForKey:@"Location"];
    if (location) {
      [prettyName appendString:@"."];
      if ([location hasPrefix:@"file"]) {
        [prettyName appendString:[location pathExtension]];
      }
      else {
        /* http:// stream address... */
        [prettyName appendString:@"webloc"];
      }
      [self setUrl:[NSURL URLWithString:location]];
    }
    [self setName:prettyName];
    [prettyName release];
  }
  return self;
}
  
- (void)dealloc {
  [self->name release];
  [self->url  release];
  [super dealloc];
}

/* accessors */

- (void)setName:(NSString *)_name {
  _name = [[_name properlyEscapedFSRepresentation] copy];
  [self->name release];
  self->name = _name;
}
- (NSString *)name {
  return self->name;
}

- (void)setUrl:(NSURL *)_url {
  _url = [_url copy];
  [self->url release];
  self->url = _url;
}
- (NSURL *)url {
  return self->url;
}

- (NSDictionary *)fileAttributes {
  if (!self->url) return nil;
  if (![self->url isFileURL]) return nil;
  return [[NSFileManager defaultManager] fileAttributesAtPath:[self->url path]
                                         traverseLink:YES];
}

- (NSData *)fileContent {
  if (!self->url) return nil;
  if (![self->url isFileURL]) { /* http based audio stream... */
    return [[self->url description] dataUsingEncoding:NSUTF8StringEncoding];
  }
  return [NSData dataWithContentsOfURL:self->url
                 options:NSMappedRead|NSUncachedRead
                 error:NULL];
}

@end /* iTunesTrack */
