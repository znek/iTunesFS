/*
  Copyright (c) 2009, Marcus Müller <znek@mulle-kybernetik.com>.
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

#import "StreamReader.h"

@interface FileHandleStreamReader : StreamReader
{
  NSFileHandle *fh;
}
@end // FileHandleStreamReader

@interface DataStreamReader : StreamReader
{
  NSData *data;
  unsigned long long offset;
}
@end // DataStreamReader


@implementation StreamReader

- (id)initWithFileHandle:(NSFileHandle *)_fh {
  [self release];
  return [[FileHandleStreamReader alloc] initWithFileHandle:_fh];
}

- (id)initWithData:(NSData *)_data {
  [self release];
  return [[DataStreamReader alloc] initWithData:_data];
}

// subclass responsibility
- (NSData *)readDataOfLength:(NSUInteger)_length {
  return nil;
}

// subclass responsibility
- (void)seekToOffset:(unsigned long long)_offset {
}

@end

@implementation FileHandleStreamReader

- (id)initWithFileHandle:(NSFileHandle *)_fh {
  self = [super init];
  if (self) {
    self->fh = [_fh retain];
  }
  return self;
}

- (void)dealloc {
  [self->fh release];
  [super dealloc];
}

- (NSData *)readDataOfLength:(NSUInteger)_length {
  return [self->fh readDataOfLength:_length];
}

- (void)seekToOffset:(unsigned long long)_offset {
  [self->fh seekToFileOffset:_offset];
}

@end // FileHandleStreamReader

@implementation DataStreamReader

- (id)initWithData:(NSData *)_data {
  self = [super init];
  if (self) {
    self->data   = [_data retain];
    self->offset = 0;
  }
  return self;
}

- (void)dealloc {
  [self->data release];
  [super dealloc];
}

- (NSData *)readDataOfLength:(NSUInteger)_length {
  NSData *d = [self->data subdataWithRange:NSMakeRange(self->offset, _length)];
  self->offset += _length;
  return d;
}

- (void)seekToOffset:(unsigned long long)_offset {
  self->offset = _offset;
}

@end // FileHandleStreamReader