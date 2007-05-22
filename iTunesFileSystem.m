/*
  Copyright (c) 2007, Marcus MŸller <znek@mulle-kybernetik.com>.
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
  return [self->lib isValidTrackName:[components objectAtIndex:2]
                    inPlaylistNamed:[components objectAtIndex:1]];
}

- (NSDictionary *)fileAttributesAtPath:(NSString *)_path {
  NSArray  *components;
  unsigned count;
  NSString *plName, *name;
  
  components = [_path pathComponents];
  count      = [components count];
  if (count < 3) return [super fileAttributesAtPath:_path];
  plName     = [components objectAtIndex:1];
  name       = [components lastObject];
  return [self->lib fileAttributesForTrackWithPrettyName:name
                    inPlaylistNamed:plName];
}

- (NSData *)contentsAtPath:(NSString *)_path {
  NSArray  *components;
  unsigned count;
  NSString *plName, *name;

  components = [_path pathComponents];
  count      = [components count];
  if (count < 3) return nil;
  plName     = [components objectAtIndex:1];
  name       = [components lastObject];
  return [self->lib fileContentForTrackWithPrettyName:name
                    inPlaylistNamed:plName];
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
  if ([_path isEqualToString:@"/"]) return fsIconPath;
  return nil;
}

@end
