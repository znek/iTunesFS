/*@DISCLAIMER@*/

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
  //  ASSIGN(self->url, _url);
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
