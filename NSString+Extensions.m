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

#include "common.h"
#include "NSString+Extensions.h"

@implementation NSString (iTunesFSExtensions)

- (NSString *)properlyEscapedFSRepresentation {
  static NSString       *colon     = nil;
  static NSCharacterSet *escapeSet = nil;

  NSRange         r;
  NSMutableString *proper;

  if (!colon) {
    const unichar colonChar = 0xFF1A; // 0xFE55
    colon     = [[NSString alloc] initWithCharacters:&colonChar length:1]; 
    escapeSet = [[NSCharacterSet characterSetWithCharactersInString:@"/:"]
                                 copy];
  }

  r = [self rangeOfCharacterFromSet:escapeSet];
  if (r.location == NSNotFound) return self;
  proper   = [self mutableCopy];
  r.length = [self length] - r.location;

  [proper replaceOccurrencesOfString:@":" withString:colon options:0 range:r];
  [proper replaceOccurrencesOfString:@"/" withString:@":"  options:0 range:r];
  return [proper autorelease];
}

@end /* NSString (iTunesFSExtensions) */

@implementation NSString (iTunesFSLittleEndianUnicode)

static char littleEndianUnicodeBom[2] = {0xFF, 0xFE};

- (id)initWithLittleEndianUnicodeData:(NSData *)_leData {
  NSMutableData *leRep;
  
  leRep = [[NSMutableData alloc] initWithCapacity:[_leData length] + 2];
  [leRep appendBytes:&littleEndianUnicodeBom length:2];
  [leRep appendData:_leData];
  
  self = [self initWithData:leRep encoding:NSUnicodeStringEncoding];
  [leRep release];
  return self;
}

@end /* NSString (iTunesFSLittleEndianUnicode) */
