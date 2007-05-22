/*@DISCLAIMER@*/

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
