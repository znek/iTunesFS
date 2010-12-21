/*
  Copyright (c) 2010, Marcus Müller <znek@mulle-kybernetik.com>.
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

#import "FUSEOFSMemoryObject.h"
#import "NSObject+FUSEOFS.h"

@implementation FUSEOFSMemoryObject

- (void)dealloc {
	[self->attrs    release];
	[self->extAttrs release];
	[super dealloc];
}

- (NSDictionary *)fileAttributes {
  if (!self->attrs)
    self->attrs = [[NSMutableDictionary alloc] initWithCapacity:6];

  BOOL isDirectory = [self isDirectory];
  if (!isDirectory && ![self->attrs objectForKey:NSFileSize]) {
    NSNumber *fileSize = [NSNumber numberWithUnsignedInteger:
                                   [[self fileContents] length]];
    [self->attrs setObject:fileSize forKey:NSFileSize];
  }
  if (![self->attrs objectForKey:NSFileType]) {
    [self->attrs setObject:isDirectory ? NSFileTypeDirectory : NSFileTypeRegular
                 forKey:NSFileType];
  }
	return [[self->attrs copy] autorelease];
}

- (BOOL)setFileAttributes:(NSDictionary *)_attrs {
  if (!self->attrs) {
    self->attrs = [[NSMutableDictionary alloc] initWithCapacity:6];
    [self->attrs setObject:[NSCalendarDate date] forKey:NSFileCreationDate];
  }
  if (_attrs)
    [self->attrs addEntriesFromDictionary:_attrs];
  return YES;
}

- (NSDictionary *)extendedFileAttributes {
  return [[self->extAttrs copy] autorelease];
}
- (BOOL)setExtendedAttribute:(NSString *)_name value:(NSData *)_value {
  if (!self->extAttrs)
    self->extAttrs = [[NSMutableDictionary alloc] initWithCapacity:2];
  [self->extAttrs setObject:_value forKey:_name];
  return YES;
}
- (BOOL)removeExtendedAttribute:(NSString *)_name {
  if (![self->extAttrs objectForKey:_name]) return NO;
  [self->extAttrs removeObjectForKey:_name];
  return YES;
}

@end /* FUSEOFSMemoryObject */
