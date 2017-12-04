/*
  Copyright (c) 2007-2015, Marcus Müller <znek@mulle-kybernetik.com>.
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

#ifndef	__iTunesFS_iTunesPlaylist_H
#define	__iTunesFS_iTunesPlaylist_H

#import <Foundation/Foundation.h>

@class iTunesFormatFile;
@class iTunesLibrary;
@class iTunesTrack;
@class iTunesM3UPlaylist;

#define kPlaylistName @"Name"
#define kPlaylistPersistentID @"Playlist Persistent ID"
#define kPlaylistParentPersistentID @"Parent Persistent ID"
#define kPlaylistIsFolder @"Folder"
#define kPlaylistItems @"Playlist Items"
#define kPlaylistTrackIDs @"trackIDs"

@interface iTunesPlaylist : NSObject
{
  NSString *persistentId;
  NSString *parentId;
  NSString *name;
  NSMutableArray *savedTracks;
  NSMutableArray *tracks;
  NSMutableArray *trackNames;
  NSMutableDictionary *childrenMap;
  iTunesFormatFile *trackFormatFile;
  iTunesM3UPlaylist *m3uPlaylist;
  id shadowFolder;
  NSDate *modificationDate;
}

- (id)initWithLibraryRepresentation:(NSDictionary *)_rep
  lib:(iTunesLibrary *)_lib;

- (NSDate *)modificationDate;

- (NSString *)name;
- (NSString *)persistentId;
- (NSString *)parentId;
- (NSArray *)tracks;

- (NSUInteger)count;
- (iTunesTrack *)trackAtIndex:(NSUInteger)_idx;
- (NSArray *)trackNames;

- (void)addChild:(iTunesPlaylist *)_child withName:(NSString *)_name;
- (NSArray *)children;

// original iTunes list of all tracks in correct order
- (NSArray *)allTracks;

@end /* iTunesPlaylist */

#endif	/* __iTunesFS_iTunesPlaylist_H */
