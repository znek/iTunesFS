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

#ifndef	__FUSEOFS_NSObject_FUSEOFS_H
#define	__FUSEOFS_NSObject_FUSEOFS_H

#import <Foundation/Foundation.h>

@interface NSObject (FUSEOFS)

/* lookup */

- (id)lookupPathComponent:(NSString *)_pc inContext:(id)_ctx;

- (NSArray *)directoryContents;
- (NSData *)fileContents;
- (NSString *)symbolicLinkTarget;

/* write support */

- (BOOL)createFileNamed:(NSString *)_name
  withAttributes:(NSDictionary *)_attrs;
- (BOOL)createDirectoryNamed:(NSString *)_name
  withAttributes:(NSDictionary *)_attrs;
- (BOOL)writeFileNamed:(NSString *)_name withData:(NSData *)_data;
- (BOOL)removeItemNamed:(NSString *)_name;

/* attributes */

- (NSDictionary *)fileAttributes;
- (BOOL)setFileAttributes:(NSDictionary *)_attrs;

- (NSDictionary *)fileSystemAttributes;

/* MacOS X _only_ attributes */

- (NSDictionary *)finderAttributes;
- (NSDictionary *)resourceAttributes;

/* misc */

// NOTE: the format of iconData is platform dependend - on MacOS X MacFUSE
// expects this to be 'icns' data
- (NSData *)iconData;

/* reflection */

- (BOOL)isDirectory;
- (BOOL)isMutable;

@end /* NSObject (FUSEOFS) */

#endif	/* __FUSEOFS_NSObject_FUSEOFS_H */
