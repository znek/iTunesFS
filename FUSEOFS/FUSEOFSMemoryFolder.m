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

#import "FUSEOFSMemoryFolder.h"
#import "NSObject+FUSEOFS.h"
#import "FUSEOFSMemoryFile.h"

@implementation FUSEOFSMemoryFolder

static NSArray *emptyArray = nil;

+ (void)initialize {
  static BOOL didInit = NO;

  if (didInit) return;
  didInit    = YES;
  emptyArray = [[NSArray alloc] init];
}

- (void)dealloc {
	[self->folder release];
	[super dealloc];
}

/* private */

- (void)setItem:(id)_item forName:(NSString *)_name {
  if (!self->folder)
    self->folder = [[NSMutableDictionary alloc] initWithCapacity:5];
  [self->folder setObject:_item forKey:_name];
  // self->attrs does already exist at this point
  [self->attrs setObject:[NSCalendarDate date] forKey:NSFileModificationDate];
}

/* FUSEOFS */

- (id)lookupPathComponent:(NSString *)_pc inContext:(id)_ctx {
  return [self->folder objectForKey:_pc];
}

/* reflection */

- (BOOL)isDirectory {
  return YES;
}
- (BOOL)isMutable {
	return YES;
}

/* read */

- (NSData *)fileContents {
	return nil;
}
- (NSArray *)directoryContents {
  if (!self->folder)
    return emptyArray;

  return [self->folder allKeys];
}

/* write */

- (BOOL)createFileNamed:(NSString *)_name
	withAttributes:(NSDictionary *)_attrs
{
  id obj = [self->folder objectForKey:_name];
  if (obj) return NO;

  FUSEOFSMemoryFile *item = [[FUSEOFSMemoryFile alloc] init];
  [item setFileAttributes:_attrs];
  [self setItem:item forName:_name];
  [item release];
  return YES;
}

- (BOOL)createDirectoryNamed:(NSString *)_name
  withAttributes:(NSDictionary *)_attrs
{
  id obj = [self->folder objectForKey:_name];
  if (obj) return NO;

  FUSEOFSMemoryFolder *item = [[FUSEOFSMemoryFolder alloc] init];
  [item setFileAttributes:_attrs];
  [self setItem:item forName:_name];
  [item release];
  return YES;
}

- (BOOL)writeFileNamed:(NSString *)_name withData:(NSData *)_data {
  FUSEOFSMemoryFile *item = [self->folder objectForKey:_name];
  if (!item) {
    FUSEOFSMemoryFile *item = [[FUSEOFSMemoryFile alloc] init];
    [self setItem:item forName:_name];
    [item release];
  }
  [item setFileContents:_data];
  return YES;
}

- (BOOL)removeItemNamed:(NSString *)_name {
  if (![self->folder objectForKey:_name]) return NO;
  [self->folder removeObjectForKey:_name];
	return YES;
}

@end /* FUSEOFSMemoryFolder */
