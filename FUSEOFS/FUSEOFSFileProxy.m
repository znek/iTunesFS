/*
  Copyright (c) 2007-2010, Marcus Müller <znek@mulle-kybernetik.com>.
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

#import "FUSEOFSFileProxy.h"
#import "NSObject+FUSEOFS.h"

@interface FUSEOFSFileProxy (Private)
- (NSString *)getRelativePath:(NSString *)_pc;
- (NSFileManager *)fileManager;
@end

@implementation FUSEOFSFileProxy

- (id)initWithPath:(NSString *)_path {
  self = [self init];
  if (self) {
    self->path = [_path copy];
  }
  return self;
}

- (void)dealloc {
  [self->path release];
  [super dealloc];
}

/* private */

- (NSString *)getRelativePath:(NSString *)_pc {
  return [self->path stringByAppendingPathComponent:_pc];
}

- (NSFileManager *)fileManager {
  return [NSFileManager defaultManager];
}

/* FUSEOFS */

- (id)lookupPathComponent:(NSString *)_pc inContext:(id)_ctx {
  if ([self isDirectory]) {
    if ([[self directoryContents] containsObject:_pc]) {
      NSString *pcPath = [self getRelativePath:_pc];
      return [[[FUSEOFSFileProxy alloc] initWithPath:pcPath] autorelease];
    }
  }
  return nil;
}

/* reflection */

- (BOOL)isDirectory {
  BOOL isDirectory;
  BOOL exists = [[self fileManager] fileExistsAtPath:self->path
                                    isDirectory:&isDirectory];
  if (!exists)
    return NO;
  return isDirectory;
}

- (BOOL)isMutable {
  if (![self isDirectory])
    return [[self fileManager] isWritableFileAtPath:self->path];
  return YES; // TODO: FIXME
}

/* read */

- (NSData *)fileContents {
  if (![self isDirectory])
    return [[self fileManager] contentsAtPath:self->path];
  return nil;
}

- (NSArray *)directoryContents {
  if ([self isDirectory])
    return [[self fileManager] contentsOfDirectoryAtPath:self->path error:NULL];
  return nil;
}

- (NSDictionary *)fileAttributes {
  return [[self fileManager] attributesOfItemAtPath:self->path error:NULL];
}

/* write */

- (BOOL)createFileNamed:(NSString *)_name
  withAttributes:(NSDictionary *)_attrs
{
  if (![self isDirectory]) return NO;
  return [[self fileManager] createFileAtPath:[self getRelativePath:_name]
                             contents:nil
                             attributes:_attrs];
}

- (BOOL)createDirectoryNamed:(NSString *)_name
  withAttributes:(NSDictionary *)_attrs
{
  if (![self isDirectory]) return NO;
  return [[self fileManager] createDirectoryAtPath:[self getRelativePath:_name]
                             withIntermediateDirectories:NO
                             attributes:_attrs
                             error:NULL];
}

- (BOOL)writeFileNamed:(NSString *)_name withData:(NSData *)_data {
  if (![self isDirectory]) return NO;
  
  return [[self fileManager] createFileAtPath:[self getRelativePath:_name]
                             contents:_data
                             attributes:nil];
}

- (BOOL)removeItemNamed:(NSString *)_name {
  if (![self isDirectory]) return NO;
  
  return [[self fileManager] removeItemAtPath:[self getRelativePath:_name]
                             error:NULL];
}

@end /* FUSEOFSFileProxy */
