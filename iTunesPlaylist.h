/*@DISCLAIMER@*/

#ifndef	__iTunesFS_iTunesPlaylist_H
#define	__iTunesFS_iTunesPlaylist_H

#import <Foundation/Foundation.h>

@class iTunesTrack;

@interface iTunesPlaylist : NSObject
{
  NSString *name;
  NSArray  *tracks;
}

- (id)initWithITunesRepresentation:(NSDictionary *)_list
  tracks:(NSDictionary *)_tracks;

- (NSString *)name;
- (NSArray *)tracks;

- (unsigned)count;
- (iTunesTrack *)trackAtIndex:(unsigned)_idx;
- (NSArray *)trackNames;

@end /* iTunesPlaylist */

#endif	/* __iTunesFS_iTunesPlaylist_H */
