/*@DISCLAIMER@*/

#ifndef	__iTunesFS_iTunesLibrary_H
#define	__iTunesFS_iTunesLibrary_H

#import <Foundation/Foundation.h>

@interface iTunesLibrary : NSObject
{
  NSDictionary        *lib;
  NSArray             *playlists; // retained by lib!
  NSDictionary        *tracks;    // retained by lib!
  NSMutableDictionary *plMap;
}

- (void)reload;

- (NSString *)libraryPath;
- (NSArray *)playlistNames;
- (NSArray *)trackNamesForPlaylistNamed:(NSString *)_plName;

- (BOOL)isValidTrackName:(NSString *)_ptn;
- (NSString *)trackIDForPrettyTrackName:(NSString *)_ptn
  inPlaylistNamed:(NSString *)_plName;

- (NSData *)dataForTrackWithID:(NSString *)_trackID;
- (NSDictionary *)fileAttributesForTrackWithID:(NSString *)_trackID;

@end /* iTunesLibrary */

#endif	/* __iTunesFS_iTunesLibrary_H */
