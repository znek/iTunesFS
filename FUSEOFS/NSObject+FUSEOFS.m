/*
  Copyright (c) 2007-2008, Marcus Müller <znek@mulle-kybernetik.com>.
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

#import "NSObject+FUSEOFS.h"

@implementation NSObject (FUSEOFS)

- (id)lookupPathComponent:(NSString *)_pc inContext:(id)_ctx {
  return nil;
}
- (NSArray *)directoryContents {
  return nil;
}
- (NSData *)fileContents {
  return nil;
}
- (NSString *)symbolicLinkTarget {
  return nil; 
}
- (NSDictionary *)fileAttributes {
  NSMutableDictionary *attrs;
  NSNumber            *perm;

  attrs = [NSMutableDictionary dictionaryWithCapacity:2];
  if ([self isDirectory]) {
    perm = [NSNumber numberWithInt:[self isMutable] ? 0700 : 0500];
    [attrs setObject:NSFileTypeDirectory forKey:NSFileType];
    [attrs setObject:[self symbolicLinkTarget] ? NSFileTypeSymbolicLink
                                               : NSFileTypeDirectory
           forKey:NSFileType];
  }
  else {
    perm = [NSNumber numberWithInt:[self isMutable] ? 0600 : 0400];
		[attrs setObject:[self symbolicLinkTarget] ? NSFileTypeSymbolicLink
                                               : NSFileTypeRegular
           forKey:NSFileType];
  }
  [attrs setObject:perm forKey:NSFilePosixPermissions];
  return attrs;
}
- (NSDictionary *)fileSystemAttributes {
  return nil;
}
- (NSDictionary *)finderAttributes {
  if ([self iconData]) {
    NSNumber *finderFlags = [NSNumber numberWithLong:kHasCustomIcon];
    return [NSDictionary dictionaryWithObject:finderFlags
						 forKey:kGMUserFileSystemFinderFlagsKey];
  }
  return nil;
}
- (NSDictionary *)resourceAttributes {
  NSData *iconData;
  
  if ((iconData = [self iconData])) {
    return [NSDictionary dictionaryWithObject:iconData
                         forKey:kGMUserFileSystemCustomIconDataKey];
  }
  return nil;
}

- (NSData *)iconData {
  return nil;
}
- (BOOL)isDirectory {
  return NO;
}
- (BOOL)isMutable {
  return NO;
}

@end /* NSObject (FUSEOFS) */

@implementation NSDictionary (FUSEOFS)

- (id)lookupPathComponent:(NSString *)_pc inContext:(id)_ctx {
  if ([_pc isEqualToString:@"_FinderAttributes"]) return nil;
  return [self objectForKey:_pc];
}
- (NSDictionary *)finderAttributes {
  id finderAttributes = [self objectForKey:@"_FinderAttributes"];
  if (finderAttributes) {
    return finderAttributes;
  }
	if ([self iconData]) {
		NSNumber *finderFlags = [NSNumber numberWithLong:kHasCustomIcon];
		return [NSDictionary dictionaryWithObject:finderFlags
                         forKey:kGMUserFileSystemFinderFlagsKey];
  }
  return nil;
}
- (NSDictionary *)resourceAttributes {
	NSData *iconData;
  
	if ((iconData = [self iconData])) {
		return [NSDictionary dictionaryWithObject:iconData
                         forKey:kGMUserFileSystemCustomIconDataKey];
	}
	return nil;
}

- (NSArray *)directoryContents {
  if (![self objectForKey:@"_FinderAttributes"])
    return [self allKeys];
  NSMutableArray *keys = [[[self allKeys] mutableCopy] autorelease];
  [keys removeObject:@"_FinderAttributes"];
  return keys;
}
- (BOOL)isDirectory {
  return YES;
}

@end /* NSDictionary (FUSEOFS) */
