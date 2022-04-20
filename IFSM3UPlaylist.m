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
#import "IFSM3UPlaylist.h"
#import "NSObject+FUSEOFS.h"
#import "IFSiTunesPlaylist.h"
#import "IFSiTunesTrack.h"
#import "IFSFormatter.h"

@implementation IFSM3UPlaylist

static BOOL useM3U8 = NO;
static NSString *fileExt = nil;

+ (void)initialize {
	static BOOL didInit = NO;
	if (didInit) return;
	didInit = YES;

	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	useM3U8 = [ud boolForKey:@"UseM3U8"];
	fileExt = [ud stringForKey:@"M3UPlaylistFileExtension"];
}

- (id)initWithPlaylist:(IFSiTunesPlaylist *)_playlist
  useRelativePaths:(BOOL)_useRelativePaths
{
	self = [super init];
	if (self) {
		self->playlist = [_playlist retain];
		self->useRelativePaths = _useRelativePaths;
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
	return [[[self name] stringByAppendingPathExtension:[self fileExtension]]
			             properlyEscapedFSRepresentation];
}
- (NSString *)fileExtension {
	if (fileExt)
		return fileExt;
	return useM3U8 ? @"m3u8" : @"m3u";
}
- (NSStringEncoding)fileEncoding {
	return useM3U8 ? NSUTF8StringEncoding : NSWindowsCP1252StringEncoding;
}

- (NSArray *)tracks {
	return self->useRelativePaths ? [self->playlist tracks]
	                              : [self->playlist allTracks];
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
	IFSFormatter *formatter = [[IFSFormatter alloc]
									                    initWithFormatString:fmt];

	NSMutableString *rep = [[NSMutableString alloc] init];
	[rep appendString:@"#EXTM3U\n"];

	NSArray *tracks = [self tracks];
	NSUInteger i, count = [tracks count];
	for (i = 0; i < count; i++) {
		IFSiTunesTrack *track =  [tracks objectAtIndex:i];
		NSString *title = [formatter stringValueByFormattingObject:track];
		[rep appendFormat:@"#EXTINF:-1,%@\n", title];

		NSURL *url = [track url];
		NSString *location;

		if ([url isFileURL]) {
			if (!self->useRelativePaths)
				location = [url path];
			else
				location = [[self->playlist trackNames] objectAtIndex:i];
		}
		else {
			location = [url description];
		}
		[rep appendString:location];
		[rep appendString:@"\n"];
	}
	NSData *d = [rep dataUsingEncoding:[self fileEncoding]];
	[rep release];
	[formatter release];
	return d;
}

@end
