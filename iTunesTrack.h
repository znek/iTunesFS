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

#ifndef	__iTunesFS_iTunesTrack_H
#define	__iTunesFS_iTunesTrack_H

#import <Foundation/Foundation.h>

#define kTrackID            @"Track ID"
#define kTrackArtist        @"Artist"
#define kTrackAlbum         @"Album"
#define kTrackNumber        @"Track Number"
#define kTrackName          @"Name"
#define kTrackLocation      @"Location"
#define kTrackSize          @"Size"
#define kTrackDateAdded     @"Date Added"
#define kTrackDateModified  @"Date Modified"
#define kTrackPlayDateUTC   @"Play Date UTC"
#define kTrackGenre         @"Genre"
#define kTrackGrouping      @"Grouping"
#define kTrackAlbumArtist   @"Album Artist"
#define kTrackComposer      @"Composer"
#define kTrackRating        @"Rating"
#define kTrackSeries        @"Series"
#define kTrackDiscNumber    @"Disc Number"
#define kTrackDiscCount     @"Disc Count"
#define kTrackPlayCount     @"Play Count"
#define kTrackYear          @"Year"
#define kTrackBitRate       @"Bit Rate"
#define kTrackSampleRate    @"Sample Rate"
#define kTrackSeasonNumber  @"Season"
#define kTrackEpisodeID     @"Episode"
#define kTrackEpisodeNumber @"Episode Order"
#define kTrackDateReleased  @"Date Released"
#define kTrackComments      @"Comments"

@interface iTunesTrack : NSObject
{
  NSString     *prettyName;
  NSString     *album;
  NSString     *artist;
  NSString     *albumArtist;
  NSString     *composer;
  NSString     *genre;
  NSString     *grouping;
  NSString     *series;
  NSString     *comments;

  NSURL        *url;
  NSDictionary *attributes;
  NSString     *ext;

  unsigned     rating;
  unsigned     discNumber;
  unsigned     discCount;
  unsigned     playCount;
  unsigned     year;
  unsigned     bitRate;
  unsigned     sampleRate;
  unsigned     seasonNumber;
  unsigned     episodeNumber;

  unsigned     trackNumber;
  unsigned     playlistNumber; // transient
}

- (id)initWithLibraryRepresentation:(NSDictionary *)_rep;

- (NSString *)name;
- (NSString *)album;
- (NSString *)artist;
- (NSString *)albumArtist;
- (NSString *)composer;
- (NSString *)genre;
- (NSString *)grouping;
- (NSString *)comments;

- (NSString *)series;
- (unsigned)seasonNumber;
- (unsigned)episodeNumber;

- (unsigned)rating;
- (unsigned)discNumber;
- (unsigned)discCount;
- (unsigned)playCount;
- (unsigned)year;
- (unsigned)bitRate;
- (unsigned)sampleRate;

- (NSString *)extension;
- (NSString *)ext;

- (unsigned)trackNumber;

- (NSURL *)url;

// whether object can be used at all in iTunesFS context
- (BOOL)isUsable;

// is it an application rather than audio/video?
- (BOOL)isApplication;


/* this is transient information, set by every playlist that needs this
 * track to format itself according to the context of the calling playlist
 */
- (void)setPlaylistNumber:(unsigned)_playlistNumber;
- (unsigned)playlistNumber;

@end /* iTunesTrack */

#endif	/* __iTunesFS_iTunesTrack_H */
