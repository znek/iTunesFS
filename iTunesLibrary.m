/*@DISCLAIMER@*/

#import "common.h"
#import "iTunesLibrary.h"
#import "NSString+Extensions.h"

@interface iTunesLibrary (Private)
- (NSString *)prettyTrackNameForTrackWithID:(NSString *)_trackID
  index:(unsigned)_idx;
@end

@implementation iTunesLibrary

static NSString *libraryPath  = nil;
static BOOL     detailedNames = NO;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  
  if (didInit) return;
  didInit       = YES;
  ud            = [NSUserDefaults standardUserDefaults];
  libraryPath   = [[ud stringForKey:@"Library"] copy];
  if (!libraryPath) {
    libraryPath = [[NSHomeDirectory() stringByAppendingString:
                                      @"/Music/iTunes/iTunes Music Library.xml"]
                                      copy];
  }
  detailedNames = [ud boolForKey:@"DetailedTrackNames"];
}

- (id)init {
  self = [super init];
  if (self) {
    [self reload];
  }
  return self;
}

- (void)dealloc {
  [self->lib   release];
  [self->plMap release];
  [super dealloc];
}

/* setup */

- (void)reload {
  NSData              *plist;
  NSMutableDictionary *map;
  unsigned            i, count;
  
  plist = [NSData dataWithContentsOfFile:[self libraryPath]];
  NSAssert1(plist != nil, @"Couldn't read contents of %@!",
                          [self libraryPath]);

  self->lib = [[NSPropertyListSerialization propertyListFromData:plist
                                            mutabilityOption:NSPropertyListImmutable
                                            format:NULL
                                            errorDescription:NULL] retain];
  NSAssert1(self->lib != nil, @"Couldn't parse contents of %@ - wrong format?!",
                              [self libraryPath]);

  self->playlists = [self->lib objectForKey:@"Playlists"];
  self->tracks    = [self->lib objectForKey:@"Tracks"];
  [self->plMap release];
  
  count = [self->playlists count];
  map   = [[NSMutableDictionary alloc] initWithCapacity:count];
  for (i = 0; i < count; i++) {
    NSDictionary *list;
    NSString     *name;

    list = [self->playlists objectAtIndex:i];
    name = [list objectForKey:@"Name"];
    [map setObject:list forKey:[name properlyEscapedFSRepresentation]];
  }
  self->plMap = map;
}

/* accessors */

- (NSString *)libraryPath {
  return libraryPath;
}

- (NSArray *)playlistNames {
  return [self->plMap allKeys];
}

- (NSArray *)trackNamesForPlaylistNamed:(NSString *)_plName {
  NSDictionary   *list;
  NSArray        *items;
  NSMutableArray *names;
  unsigned       i, count;

  list = [self->plMap objectForKey:_plName];
  if (!list) return nil;

  items = [list objectForKey:@"Playlist Items"];
  count = [items count];
  names = [[NSMutableArray alloc] initWithCapacity:count];
  for (i = 0; i < count; i++) {
    NSDictionary *item;
    id           trackID;
    NSString     *name;

    item    = [items objectAtIndex:i];
    trackID = [[item objectForKey:@"Track ID"] description];
    name    = [self prettyTrackNameForTrackWithID:trackID index:i];
    [names addObject:name];
  }
  return [names autorelease];
}

- (NSString *)prettyTrackNameForTrackWithID:(NSString *)_trackID
  index:(unsigned)_idx
{
  NSDictionary    *track;
  NSString        *name, *artist, *album;
  NSNumber        *trackNumber;
  NSString        *location;
  NSMutableString *prettyName;

  track = [self->tracks objectForKey:_trackID];
  if (!track) return nil;

  prettyName = [[NSMutableString alloc] initWithCapacity:128];
  [prettyName appendFormat:@"%03d ", _idx + 1];

  if (detailedNames) {
    artist = [track objectForKey:@"Artist"];
    if (artist) {
      [prettyName appendString:artist];
      [prettyName appendString:@"_"];
    }
    album = [track objectForKey:@"Album"];
    if (album) {
      [prettyName appendString:album];
      [prettyName appendString:@"_"];
    }
    trackNumber = [track objectForKey:@"Track Number"];
    if (trackNumber) {
      [prettyName appendString:[trackNumber description]];
      [prettyName appendString:@" "];
    }
  }
  name = [track objectForKey:@"Name"];
  [prettyName appendString:[name properlyEscapedFSRepresentation]];
#if 0
  [prettyName appendString:@" ["];
  [prettyName appendString:_trackID];
  [prettyName appendString:@"]"];
#endif
  location = [track objectForKey:@"Location"];
  if (location) {
    [prettyName appendString:@"."];
    if ([location hasPrefix:@"file"]) {
      [prettyName appendString:[location pathExtension]];
    }
    else {
      /* http:// stream address... */
      [prettyName appendString:@"webloc"];
    }
  }
  return [prettyName autorelease];
}

- (BOOL)isValidTrackName:(NSString *)_ptn {
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

- (NSString *)trackIDForPrettyTrackName:(NSString *)_ptn
  inPlaylistNamed:(NSString *)_plName
{
#if 1
  NSDictionary *list, *item;
  NSArray      *items;

  list = [self->plMap objectForKey:_plName];
  if (!list) return nil;
  
  items   = [list objectForKey:@"Playlist Items"];
  item    = [items objectAtIndex:[_ptn playlistIndex]];
  return [[item objectForKey:@"Track ID"] description];
#else
  NSRange close, open, cover;
  
  close = [_ptn rangeOfString:@"]" options:NSBackwardsSearch];
  cover = NSMakeRange(0, close.location - 1);
  open  = [_ptn rangeOfString:@"[" options:NSBackwardsSearch range:cover];
  cover = NSMakeRange(NSMaxRange(open), close.location - open.location - 1);
  return [_ptn substringWithRange:cover];
#endif
}

- (NSData *)dataForTrackWithID:(NSString *)_trackID {
  NSDictionary *track;
  NSString     *location;
  NSURL        *url;
  NSData       *data;

  track    = [self->tracks objectForKey:_trackID];
  location = [track objectForKey:@"Location"];
  if (!location) return nil;
  url  = [NSURL URLWithString:location];
  if (!url) return nil;
  if (![url isFileURL]) { /* http based audio stream... */
    return [location dataUsingEncoding:NSUTF8StringEncoding];
  }
  data = [NSData dataWithContentsOfURL:url
                 options:NSMappedRead|NSUncachedRead
                 error:NULL];
  return data;
}

- (NSDictionary *)fileAttributesForTrackWithID:(NSString *)_trackID {
  NSDictionary *track;
  NSString     *location;
  NSURL        *url;
  
  track    = [self->tracks objectForKey:_trackID];
  location = [track objectForKey:@"Location"];
  if (!location) return nil;
  url  = [NSURL URLWithString:location];
  if (![url isFileURL]) return nil;
  return [[NSFileManager defaultManager] fileAttributesAtPath:[url path]
                                         traverseLink:YES];
}

@end /* iTunesLibrary */
