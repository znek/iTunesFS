/*
  Copyright (c) 2007-2009, Marcus Müller <znek@mulle-kybernetik.com>.
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

#import "FUSEObjectFileSystem.h"
#import "common.h"
#import <MacFUSE/GMUserFileSystem.h>
#import "NSObject+FUSEOFS.h"
#import "FUSEOFSLookupContext.h"

@interface FUSEObjectFileSystem (Private)
- (id)lookupPath:(NSString *)_path;
@end

@interface NSObject (FUSEObjectFileSystem_HackHackHack)
- (NSString *)iconFileForPath:(NSString *)_path;
@end

@implementation NSObject (FUSEObjectFileSystem_HackHackHack)
- (NSString *)iconFileForPath:(NSString *)_path {
  return nil;
}
@end

@implementation FUSEObjectFileSystem

static BOOL         debugLookup = NO;
static NSDictionary *fileDict   = nil;
static NSDictionary *dirDict    = nil;
static NSDictionary *emptyDict  = nil;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  
  if (didInit) return;
  didInit     = YES;
  ud          = [NSUserDefaults standardUserDefaults];
  debugLookup = [ud boolForKey:@"FUSEObjectFileSystemDebugPathLookup"];
  fileDict    = [[NSDictionary alloc] initWithObjectsAndKeys:NSFileTypeRegular, NSFileType, nil];
  dirDict     = [[NSDictionary alloc] initWithObjectsAndKeys:NSFileTypeDirectory, NSFileType, nil];
  emptyDict   = [[NSDictionary alloc] init];
}

- (id)init {
  
  self = [super init];
  if (self) {
    self->fs = [[GMUserFileSystem alloc] initWithDelegate:self
                                         isThreadSafe:NO];
  }
  return self;
}

- (void)mountAtPath:(NSString *)_path {
  self->mountPoint = [_path copy];
  [self->fs mountAtPath:self->mountPoint
            withOptions:[self fuseOptions]];
}

- (void)unmount {
  [self->fs unmount];
}

- (void)willUnmount {
  [self->mountPoint release];
  self->mountPoint = nil;
  [self->fs unmount];
  [self->fs setDelegate:nil];
  [self->fs release];
  self->fs = nil;
}

- (NSString *)mountPoint {
  return self->mountPoint;
}

- (NSArray *)pathFromFSPath:(NSString *)_path {
  return [_path pathComponents];
}

- (id)rootObject {
  return self;
}

- (id)lookupPath:(NSString *)_path {
  NSArray  *path;
  id       obj;
  id       ctx;
  unsigned i, count;
  
  path  = [self pathFromFSPath:_path];
  count = [path count];
  if (!count) return nil;

  ctx = [[FUSEOFSLookupContext alloc] init];
  [ctx setClientObject:self];
  obj = [self rootObject];
  if (debugLookup)
    NSLog(@"lookup [#0, %@] -> %@", [path objectAtIndex:0], obj);
  for (i = 1; i < count; i++) {
    id co = obj;
    obj = [obj lookupPathComponent:[path objectAtIndex:i] inContext:ctx];
    if (i < (count - 1))
      [ctx setClientObject:co];
    if (debugLookup)
      NSLog(@"lookup [#%d, %@] -> %@", i, [path objectAtIndex:i], obj);
  }
  [ctx release];
  return obj;
}

/* required FUSE methods */

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)_path
  error:(NSError **)_err
{
  return [[self lookupPath:_path] directoryContents];
}

- (NSDictionary *)attributesOfItemAtPath:(NSString *)_path
  userData:(id)_ud
  error:(NSError **)_err
{
  NSObject *obj = [self lookupPath:_path];
  if (!obj) return nil;
  NSDictionary *attr = [obj fileAttributes];
  if (!attr)
  {
	if ([obj isDirectory])
	  return dirDict;
    else
	  return fileDict;
  }
  return attr;
}

- (NSData *)contentsAtPath:(NSString *)_path {
  return [[self lookupPath:_path] fileContents];
}

- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *)_path
  error:(NSError **)_err
{
  return [[self lookupPath:_path] symbolicLinkTarget];
}

/* optional FUSE methods */

- (NSDictionary *)finderAttributesAtPath:(NSString *)_path 
  error:(NSError **)_err
{
	return [[self lookupPath:_path] finderAttributes];
}

- (NSDictionary *)resourceAttributesAtPath:(NSString *)_path
  error:(NSError **)_err
{
  return [[self lookupPath:_path] resourceAttributes];
}

- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)_path
  error:(NSError **)_err
{
  NSDictionary *attr = [[self lookupPath:_path] fileSystemAttributes];
  if (!attr)
    attr = emptyDict;
  return attr;
}

// we need to override this method because Finder attempts to create
// several directories and the default MacFUSE implementation would
// create a runtime error
- (BOOL)createDirectoryAtPath:(NSString *)_path 
  attributes:(NSDictionary *)_attrs
  error:(NSError **)_err
{
	return NO;
}

- (NSArray *)fuseOptions {
  NSMutableArray *os;
  NSString       *volIconPath;

  os          = [NSMutableArray array];
  volIconPath = [[self rootObject] iconFileForPath:@"/"];

  if (volIconPath) {
    // this is necessary, unfortunately
    [os addObject:[@"volicon=" stringByAppendingString:volIconPath]];
  }
  return os;
}

@end /* FUSEObjectFileSystem */
