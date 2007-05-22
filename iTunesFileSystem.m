#import "common.h"
#import "iTunesFileSystem.h"
#import "iTunesLibrary.h"

@implementation iTunesFileSystem

static NSString *fsIconPath = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  NSBundle    *mb;
  
  if (didInit) return;
  didInit    = YES;
  mb         = [NSBundle mainBundle];
  fsIconPath = [[mb pathForResource:@"iTunesFS" ofType:@"icns"] copy];
  NSAssert(fsIconPath != nil, @"Couldn't find iTunesFS.icns!");
}

/* notifications */

- (void)fuseWillMount {
  self->lib = [[iTunesLibrary alloc] init];
}

- (void)fuseDidUnmount {
  [self->lib release];
}

/* required stuff */

- (NSArray *)directoryContentsAtPath:(NSString *)_path {
  NSArray  *components;
  unsigned count;
  NSString *plName;

  components = [_path pathComponents];
  count      = [components count];
  if (count < 2) /* root dir */
    return [self->lib playlistNames];
#if 0
  NSLog(@"components (%d): %@", count, components);
#endif
  plName = [components objectAtIndex:1];
  return [self->lib trackNamesForPlaylistNamed:plName];
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
  NSArray  *components;
  unsigned count;

  components = [path pathComponents];
  count      = [components count];
#if 0
  NSLog(@"components (%d): %@", count, components);
#endif
  *isDirectory = [components count] < 3 ? YES : NO;
  if (count == 1) return YES; /* root dir */
  else if (count == 2) { /* playlist */
    return [[self->lib playlistNames] containsObject:[components lastObject]];
  }
  return [self->lib isValidTrackName:[components objectAtIndex:2]];
}

- (NSDictionary *)fileAttributesAtPath:(NSString *)_path {
  NSArray  *components;
  unsigned count;
  NSString *plName, *name, *trackID;
  
  components = [_path pathComponents];
  count      = [components count];
  if (count < 3) return nil;
  plName     = [components objectAtIndex:1];
  name       = [components lastObject];
  trackID    = [self->lib trackIDForPrettyTrackName:name inPlaylistNamed:plName];
  return [self->lib fileAttributesForTrackWithID:trackID];
}

- (NSData *)contentsAtPath:(NSString *)_path {
  NSArray  *components;
  unsigned count;
  NSString *plName, *name, *trackID;

  components = [_path pathComponents];
  count      = [components count];
  if (count < 3) return nil;
  plName     = [components objectAtIndex:1];
  name       = [components lastObject];
  trackID    = [self->lib trackIDForPrettyTrackName:name inPlaylistNamed:plName];
  return [self->lib dataForTrackWithID:trackID];
}

/* optional */

#if 0
- (BOOL)shouldMountInFinder {
  return YES;
}
#endif

- (BOOL)usesResourceForks {
  return YES;
}

- (NSString *)iconFileForPath:(NSString *)_path {
  if ([_path isEqualToString:@"/"])
    return fsIconPath;
  return nil;
}

@end
