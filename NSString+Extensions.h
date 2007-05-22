/*@DISCLAIMER@*/

#ifndef	__iTunesFS_NSString_Extensions_H
#define	__iTunesFS_NSString_Extensions_H

#import <Foundation/Foundation.h>

@interface NSString (iTunesFSExtensions)

- (BOOL)isValidTrackName;
- (unsigned)playlistIndex;
- (NSString *)properlyEscapedFSRepresentation;

@end /* NSString+Extensions */

#endif	/* __iTunesFS_NSString_Extensions_H */
