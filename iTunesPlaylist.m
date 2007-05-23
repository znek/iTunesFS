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
#import "iTunesPlaylist.h"
#import "iTunesTrack.h"
#import "NSString+Extensions.h"

@interface iTunesPlaylist (Private)
- (void)setName:(NSString *)_name;
- (void)setTracks:(NSArray *)_tracks;
@end

@implementation iTunesPlaylist

- (id)initWithITunesRepresentation:(NSDictionary *)_list
  tracks:(NSDictionary *)_tracks
{
  self = [super init];
  if (self) {
    NSArray        *items;
    NSMutableArray *ts;
    unsigned       i, count;

    [self setName:[_list objectForKey:@"Name"]];
    
    items = [_list objectForKey:@"Playlist Items"];
    count = [items count];
    ts = [[NSMutableArray alloc] initWithCapacity:count];
    for (i = 0; i < count; i++) {
      NSDictionary *item;
      id           trackID;
      iTunesTrack  *track;
      
      item    = [items objectAtIndex:i];
      trackID = [[item objectForKey:@"Track ID"] description];
      item    = [_tracks objectForKey:trackID];
      track   = [[iTunesTrack alloc] initWithITunesRepresentation:item
                                     playlistIndex:i];
      [ts addObject:track];
      [track release];
    }
    [self setTracks:ts];
    [ts release];
  }
  return self;
}

- (void)dealloc {
  [self->name   release];
  [self->tracks release];
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

- (void)setTracks:(NSArray *)_tracks {
  _tracks = [_tracks copy];
  [self->tracks release];
  self->tracks = _tracks;
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
  NSMutableArray *names;
  unsigned       i, count;
  
  count = [self->tracks count];
  names = [[NSMutableArray alloc] initWithCapacity:count];
  for (i = 0; i < count; i++) {
    iTunesTrack *track;
    
    track = [self->tracks objectAtIndex:i];
    [names addObject:[track name]];
  }
  return [names autorelease];
}

@end /* iTunesPlaylist */
