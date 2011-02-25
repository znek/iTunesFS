/*
  Copyright (c) 2007-2011, Marcus Müller <znek@mulle-kybernetik.com>.
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

#import "common.h"
#import "iTunesFSFormatter.h"
#import "NSObject+FUSEOFS.h"

@interface iTunesFSFormattingResult : NSObject
{
  id              target;
  NSMutableString *buffer;
  unsigned        rewindIndex;
}

- (id)initWithTarget:(id)_obj;
- (void)appendToBuffer:(NSString *)_s;
- (void)appendValueForKeyToBuffer:(NSString *)_key;
- (NSString *)formattedString;

@end

@interface iTunesFSFormatter (Private)
- (void)setupFormattingOps;
- (void)appendStringToFormattingOps:(NSString *)_s;
- (NSString *)_stringValueByFormattingObject:(id)_obj;
@end

@implementation iTunesFSFormatter

static NSCharacterSet *wsSet                          = nil;
static NSValue        *appendToBufferValue            = nil;
static NSValue        *appendValueForKeyToBufferValue = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  SEL         selector;

  if (didInit) return;
  didInit = YES;
  wsSet   = [[NSCharacterSet whitespaceCharacterSet] copy];
  selector = @selector(appendToBuffer:);
  appendToBufferValue = \
    [[NSValue value:&selector withObjCType:@encode(SEL)] copy];
  selector = @selector(appendValueForKeyToBuffer:);
  appendValueForKeyToBufferValue = \
    [[NSValue value:&selector withObjCType:@encode(SEL)] copy];

}

- (id)initWithFormatString:(NSString *)_format {
  self = [self init];
  if (self) {
    self->format        = [_format copy];
    self->formattingOps = [[NSMutableArray alloc] initWithCapacity:5];
    [self setupFormattingOps];
  }
  return self;
}

- (void)dealloc {
  [self->format        release];
  [self->formattingOps release];
  [super dealloc];
}

- (NSString *)formatString {
  return self->format;
}

- (void)setupFormattingOps {
  NSRange         r, sr;
  unsigned        len, lastMark;

  [self->formattingOps removeAllObjects];

  len      = [self->format length];
  sr       = NSMakeRange(0, len);
  lastMark = 0;
  
  while ((r = [self->format rangeOfString:@"%("
                            options:0
                            range:sr]).length > 0)
  {
    NSRange  lr, kr;
    unsigned start;
    NSString *key;
    
    /* first copy what's missing */
    lr = NSMakeRange(lastMark, r.location - lastMark);
    if (lr.length)
      [self appendStringToFormattingOps:[self->format substringWithRange:lr]];
    
    /* find end delimiter and construct key */
    start = NSMaxRange(r);
    sr    = NSMakeRange(start, len - start);
    r     = [self->format rangeOfString:@")" options:0 range:sr];
    if (!r.length) {
      /* adjust range to end of string */
      r.length   = 0;
      r.location = len;
    }
      
    lastMark = NSMaxRange(r);
    kr       = NSMakeRange(start, r.location - start);
    key      = [self->format substringWithRange:kr];
    key      = [key stringByTrimmingCharactersInSet:wsSet];
    [self->formattingOps addObject:appendValueForKeyToBufferValue];
    [self->formattingOps addObject:key];
  }

  /* special case if no tokens were found */
  if (lastMark == 0) {
    [self appendStringToFormattingOps:self->format];
  }
  else {
    NSString *leftover;
    
    leftover = [self->format substringFromIndex:lastMark];
    [self appendStringToFormattingOps:leftover];
  }
}

- (BOOL)isPathFormat {
  return [self->format rangeOfString:@"/"].location != NSNotFound;
}

- (NSString *)stringValueByFormattingObject:(id)_obj {
  return [[self _stringValueByFormattingObject:_obj]
                properlyEscapedFSRepresentation];
}

- (NSArray *)pathComponentsByFormattingObject:(id)_obj {
  NSString *path          = [self _stringValueByFormattingObject:_obj];
  NSArray  *rawComponents = [path pathComponents];
  int      i, count       = [rawComponents count];
  NSMutableArray *components = [[NSMutableArray alloc] initWithCapacity:count];
  for (i = 0; i < count; i++) {
    NSString *rc = [rawComponents objectAtIndex:i];
    if ([rc isEqualToString:@"/"])
      continue;
    NSString *c = [[rc stringByTrimmingCharactersInSet:wsSet]
                       properlyEscapedFSRepresentation];
    if ([c length])
      [components addObject:c];
  }
  return [components autorelease];
}

- (NSString *)_stringValueByFormattingObject:(id)_obj {
  iTunesFSFormattingResult *result;
  unsigned i, count;
  NSString *formattedString;

  result = [[iTunesFSFormattingResult alloc] initWithTarget:_obj];
  count  = [self->formattingOps count];
  for (i = 0; i < count; i+= 2) {
    NSValue  *selVal;
    id       arg;
    SEL      selector;
      
    selVal = [self->formattingOps objectAtIndex:i];
    arg    = [self->formattingOps objectAtIndex:i + 1];
    [selVal getValue:&selector];
    [result performSelector:selector withObject:arg];
  }
  formattedString = [result formattedString];
  [result release];
  return formattedString;
}

- (void)appendStringToFormattingOps:(NSString *)_s {
  [self->formattingOps addObject:appendToBufferValue];
  [self->formattingOps addObject:_s];
}

@end /* iTunesFSFormatter */

@implementation iTunesFSFormattingResult

static NSMutableDictionary *fmtCache = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  
  if (didInit) return;
  fmtCache = [[NSMutableDictionary alloc] initWithCapacity:3];
}

- (id)initWithTarget:(id)_obj {
  self = [super init];
  if (self) {
    self->target = [_obj retain];
    self->buffer = [[NSMutableString alloc] initWithCapacity:20];
  }
  return self;
}

- (void)dealloc {
  [self->target release];
  [self->buffer release];
  [super dealloc];
}

- (NSFormatter *)getFormatterForValue:(id)_value
  withFormatString:(NSString *)_fmt
{
  NSString          *cacheKey;
  NSNumberFormatter *formatter;

  cacheKey  = _fmt;
  formatter = [fmtCache objectForKey:cacheKey];
  if (!formatter) {
    formatter = [[NSNumberFormatter alloc] init];
    [formatter setFormat:_fmt];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setFormatterBehavior:NSNumberFormatterBehavior10_0];
    [fmtCache setObject:formatter forKey:cacheKey];
    [formatter release];
  }
  return formatter;
}

- (void)appendToBuffer:(NSString *)_s {
  if (_s) {
    self->rewindIndex = [self->buffer length];
    [self->buffer appendString:_s];
  }
}

- (void)appendValueForKeyToBuffer:(NSString *)_key {
  NSRange     r;
  NSString    *fmt, *value;

  r = [_key rangeOfString:@"#"];
  if (r.length) {
    
    fmt  = [_key substringFromIndex:NSMaxRange(r)];
    _key = [_key substringToIndex:r.location];
  }
  else {
    fmt = nil;
  }

  NS_DURING

    value = [self->target valueForKeyPath:_key];
    if (fmt) {
      NSFormatter *formatter;
      
      formatter = [self getFormatterForValue:value withFormatString:fmt];
      value     = [formatter stringForObjectValue:value];
    }
  NS_HANDLER

    value = [localException reason];

  NS_ENDHANDLER

  if (value) {
    [self->buffer appendString:[value description]];
  }
  else {
    /* Rewind to rewindIndex - this will remove any static "prefixes"
     * In most cases this is the right thing to do, but sometimes it
     * might lead to undesired side effects. I'm nevertheless convinced
     * that this is the best choice for a default operation.
     */
    NSRange r;
    
    r = NSMakeRange(self->rewindIndex,
                    [self->buffer length] - self->rewindIndex);
    if (r.length) {
      [self->buffer deleteCharactersInRange:r];
      self->rewindIndex = [self->buffer length];
    }
  }
}

- (NSString *)formattedString {
  return [[self->buffer copy] autorelease];
}

@end /* iTunesFSFormattingResult */
