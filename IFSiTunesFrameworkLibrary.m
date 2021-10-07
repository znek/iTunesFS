/*
  Copyright (c) 2007-2021, Marcus Müller <znek@mulle-kybernetik.com>.
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
#import <iTunesLibrary/iTunesLibrary.h>
#import "IFSiTunesFrameworkLibrary.h"
#import "IFSiTunesLibrary.h"

#import "NSObject+FUSEOFS.h"
#import "NSString+Extensions.h"

#import "FUSEOFSMemoryContainer.h"
#import "IFSiTunesTrack.h"
#import "IFSiTunesPlaylist.h"
#import "IFSM3UPlaylist.h"


@interface IFSiTunesTrack (ITLib)
- (id)initWithITLibMediaItem:(ITLibMediaItem *)_item;
@end

@interface IFSiTunesPlaylist (ITLib)
- (id)initWithITLibPlaylist:(ITLibPlaylist *)_playlist
  lib:(IFSiTunesLibrary *)_lib;
@end

// FIXME
@interface IFSiTunesLibrary (Private)
- (BOOL)doDebug;
- (BOOL)useM3UPlaylists;
@end

@implementation IFSiTunesFrameworkLibrary

- (id)init {
	self = [super init];
	if (self) {
		NSError * error = nil;
		self->lib = [[ITLibrary alloc] initWithAPIVersion:@"1.0" error:&error];
		if (error) {
			NSLog(@"ERROR: %@", error);
			[self autorelease];
			return nil;
		}
		[self reload];
	}
	return self;
}

- (void)dealloc {
	[self->lib release];
	self->lib = nil;
	[super dealloc];
}

- (void)reload {
	if (!self->lib)
		return;

	if ([self doDebug])
		NSLog(@"%s", __PRETTY_FUNCTION__);

	[self->plMap    removeAllObjects];
	[self->m3uMap   removeAllObjects];
	[self->trackMap removeAllObjects];

	for (ITLibMediaItem *item in [self->lib allMediaItems]) {
		IFSiTunesTrack  *track = [[IFSiTunesTrack alloc]
								                   initWithITLibMediaItem:item];
		if ([track isUsable])
		  [self->trackMap setObject:track forKey:[item persistentID]];
		[track release];
	}

	NSArray *allPlaylists = [self->lib allPlaylists];
	NSUInteger count = [allPlaylists count];

	NSMutableDictionary *idPlMap = [[NSMutableDictionary alloc]
									                      initWithCapacity:count];

	for (ITLibPlaylist *playlist in allPlaylists) {
		IFSiTunesPlaylist *pl = [[IFSiTunesPlaylist alloc]
								                     initWithITLibPlaylist:playlist
										             lib:self];

		// only record top-level playlist, if playlist isn't a folder itself
		if (![pl parentId]) {
		  [self->plMap setItem:pl
					   forName:[self burnFolderNameFromFolderName:[pl name]]];
		}
		id plId = [pl persistentId];
		if (plId)
		  [idPlMap setObject:pl forKey:plId];
		[pl release];
	}


	// connect children to their parents
	if ([idPlMap count]) {
		NSArray *ids = [idPlMap allKeys];
		for (id plId in ids) {
			IFSiTunesPlaylist *pl = [idPlMap objectForKey:plId];
			id parentId = [pl parentId];
			if (parentId) {
				IFSiTunesPlaylist *parent = [idPlMap objectForKey:parentId];
				if (parent) {
				  [parent addChild:pl
						  withName:[self burnFolderNameFromFolderName:[pl name]]];
				}
				else {
				  NSLog(@"ERROR: didn't find parent playlist of '%@'?!", pl);
				}
			}
		}
	}

	if ([self useM3UPlaylists]) {
		for (IFSiTunesPlaylist *pl in [idPlMap allValues]) {
		  if (![[pl allTracks] count])
			continue;

		  IFSM3UPlaylist *m3uPl = [[IFSM3UPlaylist alloc]
												    initWithPlaylist:pl
												    useRelativePaths:NO];
		  [self->m3uMap setItem:m3uPl forName:[m3uPl fileName]];
		  [m3uPl release];
		}
	}

	[idPlMap release];
	[self reloadVirtualMaps];
}

- (void)close {
}

- (NSString *)name {
	return @"iTunes Framework";
}

/* debugging */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%s %p: name:%@>",
				    object_getClassName(self), self,
				    [self name]];
}

/* FIXME */

- (NSString *)mountPoint {
	return nil;
}

@end

@interface IFSiTunesTrack (Private)
- (void)setAttributes:(NSDictionary *)_attributes;
- (void)setPrettyName:(NSString *)_prettyName;
- (void)setTrackNumber:(NSUInteger)_trackNumber;
- (void)setUrl:(NSURL *)_url;
@end

@implementation IFSiTunesTrack (ITLib)

- (id)initWithITLibMediaItem:(ITLibMediaItem *)_item {
	self = [super init];
	if (self) {
		NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
		NSString *locationReplacePrefix = [ud stringForKey:@"LocationReplacePrefix"];
		NSString *locationDestinationPrefix = [ud stringForKey:@"LocationDestinationPrefix"];
		BOOL useSymbolicLinks = [ud boolForKey:@"SymbolicLinks"];

		ITLibAlbum *_album = [_item album];
		ITLibMediaItemVideoInfo *_info = [_item videoInfo];

		self->artist = [[[[_item artist] name] properlyEscapedFSRepresentation] copy];
		self->album  = [[[_album title] properlyEscapedFSRepresentation] copy];

		self->albumArtist   = [[[_album albumArtist] properlyEscapedFSRepresentation] copy];
		self->composer      = [[[_item composer] properlyEscapedFSRepresentation] copy];
		self->genre         = [[[_item genre] properlyEscapedFSRepresentation] copy];
		self->grouping      = [[[_item grouping] properlyEscapedFSRepresentation] copy];
		// FIXME
		self->series        = [[[_info series] properlyEscapedFSRepresentation] copy];
		self->comments      = [[[_item comments] properlyEscapedFSRepresentation] copy];

		self->rating        = [_item rating];
		self->discNumber    = [_album discNumber];
		if (self->discNumber == 0)
		  self->discNumber = 1;
		self->discCount     = [_album discCount];
		if (self->discCount == 0)
		  self->discCount = 1;
		self->playCount     = [_item playCount];
		self->year          = [_item year];
		self->bitRate       = [_item bitrate];
		self->sampleRate    = [_item sampleRate];
		self->seasonNumber  = [_info season];
		self->episodeNumber = [_info episode];

		[self setTrackNumber:[_item trackNumber]];

		NSString *name = [_item title];
		if (name) {
		  [self setPrettyName:[name properlyEscapedFSRepresentation]];
		}
		else {
		  NSLog(@"WARN: item without name! %@", _item);
		  [self setPrettyName:@"Empty"];
		}
		NSString *location = [[_item location] absoluteString];
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

		NSMutableDictionary *attrs = [[NSMutableDictionary alloc]
														   initWithCapacity:3];

		if ([[self url] isFileURL]) {
			[attrs setObject:[NSNumber numberWithLongLong:[_item fileSize]] forKey:NSFileSize];
		}
		id tmp = [_item addedDate];
		if (tmp)
			[attrs setObject:tmp forKey:NSFileCreationDate];
		tmp = [_item modifiedDate];
		if (tmp) {
			[attrs setObject:tmp forKey:NSFileModificationDate];
		}
		else {
			tmp = [_item lastPlayedDate];
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

@end

@interface IFSiTunesPlaylist (Private)
- (void)generatePrettyTrackNames;
- (void)setName:(NSString *)_name;
@end

@implementation IFSiTunesPlaylist (ITLib)

- (id)initWithITLibPlaylist:(ITLibPlaylist *)_playlist
  lib:(IFSiTunesLibrary *)_lib
{
	self = [self init];
	if (self) {
		[self setName:[_playlist name]];
		self->persistentId = [[_playlist persistentID] copy];
		self->parentId     = [[_playlist parentID] copy];

		BOOL isFolder = ([_playlist kind] == ITLibPlaylistKindFolder);
		if (!isFolder) {
			for (ITLibMediaItem *item in [_playlist items]) {
				NSNumber *trackID = [item persistentID];
				IFSiTunesTrack *trk = [_lib trackWithID:trackID];
				if (!trk) {
				  if ([_lib doDebug])
					NSLog(@"Playlist[%@]: found no track item for #%@",
						  self->name, trackID);
				  continue;
				}
				[self->savedTracks addObject:trk];
			}
			[self generatePrettyTrackNames];
		}
	}
	return self;
}

@end

