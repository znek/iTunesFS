/*@DISCLAIMER@*/

#ifndef	__iTunesFS_iTunesTrack_H
#define	__iTunesFS_iTunesTrack_H

#import <Foundation/Foundation.h>

@interface iTunesTrack : NSObject
{
  NSString *name;
  NSURL    *url;
}

+ (void)setUseDetailedInformationInNames:(BOOL)_yn;

- (id)initWithITunesRepresentation:(NSDictionary *)_track
  playlistIndex:(unsigned)_idx;

- (NSString *)name;
- (NSDictionary *)fileAttributes;
- (NSData *)fileContent;
  
@end /* iTunesTrack */

#endif	/* __iTunesFS_iTunesTrack_H */
