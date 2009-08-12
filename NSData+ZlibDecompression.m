/*
  NSData+ZlibDecompression.m created by znek on Sat 26-Jun-1999
  originally created as part of the MMCompression framework.
  Copyright (c) 1999, 2000 by Marcus Mueller <znek@mulle-kybernetik.com>
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


#import "NSData+ZlibDecompression.h"
#include <zlib.h>

NSString *ZlibDecompressionBlockSize = @"ZlibDecompressionBlockSize";

#define ZlibDefaultDecompressionBlockSize 8192

#define ZLIB_ERROR(STRING) [NSException raise:NSInternalInconsistencyException format:@"<%@:0x%p %@> %@ (%d)", [self class], self, NSStringFromSelector(_cmd), (STRING), success]


// RFC1952

// FLG bits
#define FTEXT     0x01 /* bit 0 set: file probably ascii text */
#define FHCRC     0x02 /* bit 1 set: header CRC present */
#define FEXTRA    0x04 /* bit 2 set: extra field present */
#define FNAME     0x08 /* bit 3 set: original file name present */
#define FCOMMENT  0x10 /* bit 4 set: file comment present */
#define RESERVED  0xE0 /* bits 5..7: reserved */


@interface NSData (ZlibDecompression_private)
- (BOOL)_hasGZIPFileHeader;
- (int)_gzipFileHeaderLength;
@end


@implementation NSData(ZlibDecompression)

- (NSData *)decompressedDataUsingZlib {
  return [self decompressedDataUsingZlibWithArguments:nil];
}

- (NSData *)decompressedDataUsingZlibWithArguments:(NSDictionary *)arguments {
  int  blocksize;
  
  id anArgument = [arguments objectForKey:ZlibDecompressionBlockSize];
  if (anArgument) {
    blocksize = [anArgument intValue];
    if (blocksize <= 0)
      [NSException raise:NSInvalidArgumentException format:@"ZlibDecompressionBlockSize argument <= 0"];
  }
  else {
    blocksize = ZlibDefaultDecompressionBlockSize;
  }
  
  NSMutableData * decompressedData = [[[NSMutableData allocWithZone:[self zone]]
                                                      initWithLength:blocksize]
                                                      autorelease];

  z_stream stream;
  memset(&stream, 0, sizeof(stream)); // initialize stream
  stream.next_in   = (unsigned char *)[self bytes];
  stream.avail_in  = [self length];
  stream.avail_out = blocksize;
  stream.next_out  = (unsigned char *)[decompressedData mutableBytes];
  
  BOOL hasFileHeader = [self _hasGZIPFileHeader];
  if (hasFileHeader) {
    // skip the header
    int headerLength = [self _gzipFileHeaderLength];
    stream.avail_in -= headerLength;
    stream.next_in  += headerLength;
  }
  
  // this switches automatically from transparent to non-transparent mode
  // streams use transparent mode (with header), gzip does not do so (and wants to skip that header)
  int success = inflateInit2(&stream, hasFileHeader ? -MAX_WBITS : MAX_WBITS);
  if (success != Z_OK) {
    if (success == Z_MEM_ERROR)
      ZLIB_ERROR(@"insufficient memory");
    else
		  ZLIB_ERROR(@"inflateInit returned an error");
  }

  do {
    if (stream.avail_out == 0) {
      [decompressedData increaseLengthBy:blocksize];
      stream.avail_out = blocksize;
      stream.next_out = [decompressedData mutableBytes] + stream.total_out;
    }
    success = inflate(&stream, Z_NO_FLUSH);
  } while((success == Z_OK) || (success == Z_NEED_DICT));
  
  // release all memory first before complaining about errors
  [decompressedData setLength:stream.total_out]; // adjust length
  inflateEnd(&stream); // release all memory associated with decompression stream
  
  if (success != Z_STREAM_END) {
    if( success == Z_MEM_ERROR)
      ZLIB_ERROR(@"insufficient memory");
    else
      ZLIB_ERROR(@"inflate returned an error");
  }
  
  return decompressedData;
}

// We'd like to be able to decompress gzipped files as well as any zlib stream
// gzipped files do have a header with a magic, whereas zlib streams have
// no magic!
- (BOOL)isZlibCompressed {
  if ([self _hasGZIPFileHeader]) return YES;

#ifndef STABLE
//#warning * enabled the testing of streams which may result in failures on rare occasions!
  else {
    if ([self length] > 2) {
      // Now, that's a bit inefficient.
      // We decompress the first few bytes of a zlib stream and see if it complains.
      // If everything works ok, this is a zlib stream.
      NSMutableData *decompressedData;
      z_stream stream;
      int success;
      int blocksize = 1; // a simple test buffer
      
      decompressedData = [[[NSMutableData allocWithZone:[self zone]]
                           initWithLength:blocksize] autorelease];
      memset(&stream, 0, sizeof(stream)); // initialize stream
      stream.next_in   = (unsigned char *)[self bytes];
      stream.avail_in  = [self length];
      stream.avail_out = blocksize;
      stream.next_out  = (unsigned char *)[decompressedData mutableBytes];
      
      success = inflateInit(&stream);
      if (success == Z_OK) {
        success = inflate(&stream, Z_NO_FLUSH);
        if ((success == Z_OK) || (success = Z_STREAM_END)) {
          // clean up memory allocation
          inflateEnd(&stream); // release all memory associated with decompression stream
          return YES; // this is a zlib stream
        }
      }
      // clean up memory allocation
      inflateEnd(&stream);
    }
  }
#endif
  return NO;
}

@end

@implementation NSData (ZlibDecompression_private)

- (BOOL)_hasGZIPFileHeader {
  if ([self length] > 10) {
    // taken from gzio.c, but modified to char
    static char gz_magic[2] = {0x1f, 0x8b}; /* gzip magic header */

    // is it a gzipped file?
    char *bytes = (char *)[self bytes];
    if (bytes[0] == gz_magic[0] && bytes[1] == gz_magic[1])
      return YES;
  }
  return NO;
}

- (int)_gzipFileHeaderLength {
  char *header = (char *)[self bytes];
  int  flg     = header[3];
  int  length  = 10;

  if (flg & FEXTRA)
    length += (unsigned int)header[length] + 2; // bytes + length field
  if (flg & FNAME) {
    while (header[length])
      length++;
    length++;
  }
  if (flg & FCOMMENT) {
    while (header[length])
      length++;
    length++;
  }
  if (flg & FHCRC)
    length += 2;

  return length;
}

@end
