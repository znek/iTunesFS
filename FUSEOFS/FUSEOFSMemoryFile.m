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

#import "FUSEOFSMemoryFile.h"
#import "NSObject+FUSEOFS.h"

@implementation FUSEOFSMemoryFile

static NSDictionary *emptyDict = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  
  if (didInit) return;
  didInit   = YES;
  emptyDict = [[NSDictionary alloc] init];
}

- (void)dealloc {
	[self->data  release];
  [self->attrs release];
	[super dealloc];
}

/* accessors */

- (void)setAttributes:(NSDictionary *)_attrs {
  if (!self->attrs) {
    self->attrs = [[NSMutableDictionary alloc] initWithCapacity:2];
    [self->attrs setObject:NSFileTypeRegular forKey:NSFileType];
  }
  [self->attrs addEntriesFromDictionary:_attrs];
}

- (void)setData:(NSData *)_data {
  if (self->data == _data) return;
  [self->data release];
  self->data = [_data copy];
}

/* FUSEOFS */

- (id)lookupPathComponent:(NSString *)_pc inContext:(id)_ctx {
  return nil;
}

/* reflection */

- (BOOL)isDirectory {
  return NO;
}
- (BOOL)isMutable {
	return NO;
}

/* read */

- (NSData *)fileContents {
	return self->data;
}
- (NSArray *)directoryContents {
  return nil;
}
- (NSDictionary *)fileAttributes {
	return [[self->attrs copy] autorelease];
}

@end /* FUSEOFSMemoryFile */

