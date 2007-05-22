/*@DISCLAIMER@*/

#include "common.h"
#include "NSString+Extensions.h"

@implementation NSString (iTunesFSExtensions)

- (BOOL)isValidTrackName {
#if 1
  NSRange  r;
  unsigned len, i;

  len = [self length];
  if (len < 4) return NO;
  r = [self rangeOfString:@" " options:0 range:NSMakeRange(3, len - 3)];
  if (r.location == NSNotFound) return NO;
  for (i = r.location - 1; i > 0; --i) {
    unichar  c;
    
    c = [self characterAtIndex:i];
    if (c < '0' || c > '9') {NSLog(@"%@ [%d]-> NO", self, i); return NO;}
  }
  return YES;
#else
  return [_ptn rangeOfString:@"]" options:NSBackwardsSearch].location != NSNotFound;
#endif
}

- (unsigned)playlistIndex {
  NSRange r;
  int     i;

  r = [self rangeOfString:@" "];
  if (r.location == NSNotFound) return 0;
  i = [[self substringToIndex:r.location] intValue];
  return i - 1;
}

- (NSString *)properlyEscapedFSRepresentation {
  NSRange         r;
  NSMutableString *proper;

  r = [self rangeOfString:@"/"];
  if (r.location == NSNotFound) return self;
  proper   = [self mutableCopy];
  r.length = [self length] - r.location;

  /* NOTE: the Finder will properly unescape ":" into "/" when presenting
   *       this to the user.
   */
  [proper replaceOccurrencesOfString:@"/" withString:@":" options:0 range:r];
  return [proper autorelease];
}

@end /* NSString+Extensions */
