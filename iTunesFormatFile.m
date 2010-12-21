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

#import "iTunesFormatFile.h"
#import "iTunesFSFormatter.h"
#import "NSObject+FUSEOFS.h"

@interface iTunesFormatFile (Private)
- (void)_setup;
- (NSString *)defaultKeyForTemplateId:(NSString *)_id;
- (NSString *)templateDefaultFormatString;
- (NSString *)templateFormatString;
@end

@implementation iTunesFormatFile

static BOOL           doDebug  = NO;
static NSCharacterSet *trimSet = nil;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;

  if (didInit) return;
  didInit = YES;
  ud      = [NSUserDefaults standardUserDefaults];
  doDebug = [ud boolForKey:@"iTunesFormatFileDebugEnabled"];
  trimSet = [[NSCharacterSet characterSetWithCharactersInString:@"\n\r\t "]
                             copy];
}

- (id)initWithDefaultTemplate:(NSString *)_defTemplate
  templateId:(NSString *)_templateId
{
	self = [self init];
  if (self) {
    self->defaultTemplate = [_defTemplate copy];
    if (_templateId) {
      self->defaultKey = [[self defaultKeyForTemplateId:_templateId] copy];
    }
    self->needsSetup = YES;
  }
  return self;
}

- (void)dealloc {
  [self->defaultTemplate release];
  [self->defaultKey release];
  [super dealloc];
}

/* private */

- (void)_setup {
  static NSString *helpText = nil;
  if (!helpText) {
    NSString *htPath = [[NSBundle mainBundle]
                                  pathForResource:self->defaultTemplate
                                  ofType:@"txt"];
    if (htPath) {
      helpText = [[NSString alloc] initWithContentsOfFile:htPath
                                   encoding:NSUTF8StringEncoding
                                   error:NULL];
    }
  }

  NSMutableString *format = [[NSMutableString alloc] initWithCapacity:1024];
  [format appendString:@"# "];
  [format appendString:self->defaultKey];
  [format appendString:@"\n#\n"];
  if (helpText) {
    [format appendString:helpText];
    [format appendString:@"\n"];
  }
  [format appendString:[self templateFormatString]];
  [format appendString:@"\n"];
  NSData *formatData = [format dataUsingEncoding:NSUTF8StringEncoding];
  [format release];
  [super setFileContents:formatData];
}

- (NSString *)defaultKeyForTemplateId:(NSString *)_id {
  return [NSString stringWithFormat:@"%@[%@]", self->defaultTemplate, _id];
}

- (NSString *)templateDefaultFormatString {
  return [[NSUserDefaults standardUserDefaults]
                          stringForKey:self->defaultTemplate];
}

- (NSString *)templateFormatString {
  if (!self->defaultKey)
    return [self templateDefaultFormatString];
  
  NSString *fmt = [[NSUserDefaults standardUserDefaults]
                                   stringForKey:self->defaultKey];
  // might be null because currently not set!
  if (!fmt)
    fmt = [self templateDefaultFormatString];
  return fmt;
}

/* accessors */

- (iTunesFSFormatter *)getFormatter {
  NSString *fmt;

  if (self->defaultKey) {
    NSUserDefaults *ud     = [NSUserDefaults standardUserDefaults];
    NSString       *fmtKey = self->defaultKey;
    if (fmt = [ud stringForKey:fmtKey]) {
      // is it an alias?
      if ([fmt hasPrefix:@"@"] && ([fmt length] > 1)) {
        fmt = [fmt substringFromIndex:1];
        if (doDebug)
          NSLog(@"%@ is an alias to %@", self->defaultKey, fmt);
        fmtKey = [self defaultKeyForTemplateId:fmt];
        fmt    = [ud stringForKey:fmtKey];
      }
      if (fmt) {
        return [[[iTunesFSFormatter alloc] initWithFormatString:fmt]
                                           autorelease];
      }
      else {
        if (doDebug)
          NSLog(@"WARN: no format found for reference %@", fmtKey);
      }
    }
  }
  fmt = [self templateDefaultFormatString];
  return [[[iTunesFSFormatter alloc] initWithFormatString:fmt] autorelease];
}

- (void)remove {
  if (self->defaultKey) {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:self->defaultKey];
  }
  self->needsSetup = YES;
}

/* FUSEOFS */

- (void)setFileContents:(NSData *)_data {
  // NOTE: this is just a quick hack, but should be refactored to a more
  // robust implementation once we settle on this concept.

  NSString *rawDefault = [[[NSString alloc] initWithData:_data
                                            encoding:NSUTF8StringEncoding]
                                            autorelease];
  if (doDebug)
    NSLog(@"%s rawDefault(before trimming):\n%@", _cmd, rawDefault);
  rawDefault = [rawDefault stringByTrimmingCharactersInSet:trimSet];
  NSArray  *lines      = [rawDefault componentsSeparatedByString:@"\n"];
  NSString *newDefault = [lines lastObject];
  if (newDefault && [newDefault length]) {
    [[NSUserDefaults standardUserDefaults] setObject:newDefault
                                           forKey:self->defaultKey];
    self->needsSetup = YES;
    if (doDebug)
      NSLog(@"%s %@ = %@", _cmd, self->defaultKey, newDefault);
  }
  else {
    [self remove];
    if (doDebug)
      NSLog(@"%s -> removed %@", _cmd, self->defaultKey);
  }
}

- (NSData *)fileContents {
  if (self->needsSetup) {
    [self _setup];
    self->needsSetup = NO;
  }
  return [super fileContents];
}

- (NSDictionary *)extendedFileAttributes {
  if (!self->extAttrs) {
    static NSData *attrVal = nil;
    if (!attrVal) {
      CFStringRef ianaCharSetName = 
        CFStringConvertEncodingToIANACharSetName(kCFStringEncodingUTF8);
      
      NSString *attr = [NSString stringWithFormat:@"%@;%d", ianaCharSetName,
                                                  kCFStringEncodingUTF8];
      attrVal = [[attr dataUsingEncoding:NSASCIIStringEncoding] copy];
    }
    self->extAttrs = [[NSMutableDictionary alloc] initWithCapacity:2];
    [self setExtendedAttribute:@"com.apple.TextEncoding" value:attrVal];
  }
  return [super extendedFileAttributes];
}

@end /* iTunesFormatFile */
