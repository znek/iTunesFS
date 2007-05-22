#import <Foundation/Foundation.h>
#import "FUSEFileSystem.h"

@class iTunesLibrary;

@interface iTunesFileSystem : FUSEFileSystem
{
  iTunesLibrary *lib;
}

@end
