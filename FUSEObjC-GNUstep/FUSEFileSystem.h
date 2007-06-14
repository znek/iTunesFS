//
//  FUSEFileSystem.h
//  FUSEObjC
//
//  Created by alcor on 12/6/06.
//  Copyright 2006 Google. All rights reserved.
//

#import <AppKit/AppKit.h>
@class FUSEFileWrapper;

@interface FUSEFileSystem : NSObject {
  NSDictionary *files_;
  NSString *mountPoint_;
  BOOL isMounted_;  // Should Finder see that this filesystem has been mounted? 
}
+ (FUSEFileSystem *)sharedManager;

//
// Required methods
//

- (NSArray *)directoryContentsAtPath:(NSString *)path; // Array of NSStrings
- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory;
- (NSDictionary *)fileAttributesAtPath:(NSString *)path;
- (NSData *)contentsAtPath:(NSString *)path;

//
// Optional methods
//

// #pragma mark Resource Forks

- (BOOL)usesResourceForks; // Enable resource forks (icons, weblocs, more)

// #pragma mark Writing

- (BOOL)createDirectoryAtPath:(NSString *)path attributes:(NSDictionary *)attributes;

 // TODO: Support the single-shot create with data if we can.
 //- (BOOL)createFileAtPath:(NSString *)path contents:(NSData *)contents 
 //              attributes:(NSDictionary *)attributes;
- (BOOL)createFileAtPath:(NSString *)path attributes:(NSDictionary *)attributes;
- (BOOL)movePath:(NSString *)source toPath:(NSString *)destination handler:(id)handler;
- (BOOL)removeFileAtPath:(NSString *)path handler:(id)handler;


// #pragma mark Lifecycle

- (NSString *)mountName;
- (NSString *)mountPoint;

- (BOOL)shouldMountInFinder; // Defaults to NO
- (BOOL)shouldStartFuse;

- (void)fuseWillMount;
- (void)fuseDidMount;

- (void)fuseWillUnmount;
- (void)fuseDidUnmount;


// #pragma mark Special Files

- (NSDictionary *)fileSystemAttributesAtPath:(NSString *)path;

// Contents for a symbolic link (must have specified NSFileType as NSFileTypeSymbolicLink)
- (NSString *)pathContentOfSymbolicLinkAtPath:(NSString *)path;
- (BOOL)createSymbolicLinkAtPath:(NSString *)path pathContent:(NSString *)otherPath;
- (BOOL)linkPath:(NSString *)source toPath:(NSString *)destination handler:(id)handler;


//
// Advanced functions
//


// #pragma mark Advanced File Operations

- (id)openFileAtPath:(NSString *)path mode:(int)mode;
- (int)readFileAtPath:(NSString *)path handle:(id)handle
               buffer:(char *)buffer size:(size_t)size offset:(off_t)offset;

- (int)writeFileAtPath:(NSString *)path handle:(id)handle buffer:(const char *)buffer
                  size:(size_t)size offset:(off_t)offset;
- (void)releaseFileAtPath:(NSString *)path handle:(id)handle;

- (BOOL)fillStatBuffer:(struct stat *)stbuf forPath:(NSString *)path;
- (BOOL)fillStatvfsBuffer:(struct statvfs *)stbuf forPath:(NSString *)path;

- (BOOL)truncateFileAtPath:(NSString *)path offset:(off_t)offset;

@end

