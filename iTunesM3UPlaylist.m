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

#import "common.h"
#import "iTunesM3UPlaylist.h"
#import "NSObject+FUSEOFS.h"
#import "iTunesPlaylist.h"
#import "iTunesTrack.h"
#import "iTunesFSFormatter.h"

@implementation iTunesM3UPlaylist

- (id)initWithPlaylist:(iTunesPlaylist *)_playlist {
	self = [super init];
	if (self) {
		self->playlist = [_playlist retain];
	}
	return self;
}

- (void)dealloc {
	[self->playlist release];
	[super dealloc];
}

/* Properties */

- (NSString *)name {
	return [self->playlist name];
}
- (NSString *)fileName {
	return [[[self name] stringByAppendingPathExtension:@"m3u"]
			             properlyEscapedFSRepresentation];
}

/* FUSEOFS */

- (BOOL)isContainer {
	return NO;
}
- (BOOL)isMutable {
	return NO;
}

- (NSDictionary *)fileAttributes {
	NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithCapacity:5];
	[attrs setObject:[self->playlist modificationDate]
		   forKey:NSFileCreationDate];
	[attrs setObject:[self->playlist modificationDate]
		   forKey:NSFileModificationDate];
	[attrs setObject:NSFileTypeRegular forKey:NSFileType];
	NSNumber *perm = [NSNumber numberWithInt:[self isMutable] ? 0666 : 0444];
	[attrs setObject:perm forKey:NSFilePosixPermissions];
	return attrs;
}

- (NSData *)fileContents {
	NSString *fmt = [[NSUserDefaults standardUserDefaults]
									  stringForKey:@"M3UTrackFormat"];
	iTunesFSFormatter *formatter = [[iTunesFSFormatter alloc]
									                    initWithFormatString:fmt];

	NSMutableString *rep = [[NSMutableString alloc] init];
	[rep appendString:@"#EXTM3U\n"];
	for (iTunesTrack *track in [self->playlist allTracks]) {
		NSString *title = [formatter stringValueByFormattingObject:track];
		NSURL *url = [track url];
		NSString *location = [url isFileURL] ? [url path] : [url description];

		[rep appendFormat:@"#EXTINF:-1,%@\n", title];
		[rep appendString:location];
		[rep appendString:@"\n"];
	}
	NSData *d = [rep dataUsingEncoding:NSUTF8StringEncoding];
	[rep release];
	[formatter release];
	return d;
}

@end
