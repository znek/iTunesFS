//
//  FUSEFileSystem.m
//  FUSEObjC
//
//  Created by alcor on 12/6/06.
//  Copyright 2006 Google. All rights reserved.
//

#import "FUSEFileSystem.h"
#define FUSE_USE_VERSION 26
#include <fuse.h>

#include <string.h>
#include <errno.h>
#include <fcntl.h>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/param.h>
#include <sys/mount.h>

@interface NSString (UTF8Copy)
- (char *)copyUTF8String;
@end
@implementation NSString (UTF8Copy)
- (char *)copyUTF8String {
  const char *original = [self UTF8String];
  size_t len = strlen(original)+1;
  char *copy = malloc(len);
  strlcpy(copy, original, len);
  return copy;
}
@end

@interface NSString (UniquePath)
-(NSString *)firstUnusedFilePath;
@end

@implementation NSString (UniquePath)
-(NSString *)firstUnusedFilePath{
	NSString *basePath=[self stringByDeletingPathExtension];
	NSString *extension=[self pathExtension];
	NSString *alternatePath=self;
	int i;
	for (i=1;[[NSFileManager defaultManager] fileExistsAtPath:alternatePath]; i++)
		alternatePath=[NSString stringWithFormat:@"%@ %d.%@",basePath,i,extension];
	return alternatePath;
}

@end


@interface NSData (BufferOffset) 
- (int)getBytes:(char *)buf size:(size_t)size offset:(off_t)offset;
@end

@implementation NSData (BufferOffset) 
- (int)getBytes:(char *)buf size:(size_t)size offset:(off_t)offset {
  size_t len = [self length];
  if (offset + size > len)
    size = len - offset;
  
  if (offset > len) {
    NSLog(@"read too many bytes %d > %d", offset, len);
    return 0;
  }
  
  NSRange range = NSMakeRange(offset, size);
  [self getBytes:buf range:range];
  return size;
}
@end


#ifdef GNUSTEP_BASE_LIBRARY

@interface NSBundle (OSXJaguarAdditions)

- (id)objectForInfoDictionaryKey:(NSString *)_key;

@end

@implementation NSBundle (OSXJaguarAdditions)

- (id)objectForInfoDictionaryKey:(NSString *)_key {
  return [[self infoDictionary] objectForKey:_key];
}

@end

#endif


// #pragma mark -

static FUSEFileSystem *manager;


@interface FUSEFileSystem (FUSEFileSystemPrivate)
- (NSArray *)fullDirectoryContentsAtPath:(NSString *)path;
- (void)startFuse;
- (void)stopFuse;
@end

@interface FUSEFileSystem (FuseFunctions)

//- (void)fuseInit;
//- (void)fuseDestroy;
//- (BOOL)shouldStartFuse;
//- (NSString *)mountName;
//- (NSString *)mountPoint;

@end



@implementation FUSEFileSystem

+ (void)initialize {
  NSDictionary *defaults = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSUserDefaults"];
  if (defaults)
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (id)init {
  if (manager) {
    [self release];
    return manager;  
  }
  
  // FUSEFileSystem automatically converts into the desired subclass
  if ([self isMemberOfClass:[FUSEFileSystem class]]) {
    [self release];
    NSString *fuseClassName =
      [[NSBundle mainBundle] objectForInfoDictionaryKey:@"FUSEFileSystemClass"];
    Class fuseClass = NSClassFromString(fuseClassName);
    if (fuseClass && fuseClass != [FUSEFileSystem class]) {
      
      self = [[fuseClass alloc] init];
      isMounted_ = NO;
    } else {
      NSLog(@"Could not find class: %@", fuseClassName);
      return nil;
    }
  }
  manager = self;
  return manager;
}

+ (FUSEFileSystem *)sharedManager {
  if (!manager) {
    manager = [[self alloc] init];
  }
  return manager;
}

// #pragma mark Resource Forks and HFS headers

- (BOOL)usesResourceForks{
  return NO;
}

// #pragma mark Attributes

- (NSDictionary *)fileSystemAttributesAtPath:(NSString *)path {
  return nil;
}

- (BOOL)fillStatvfsBuffer:(struct statvfs *)stbuf forPath:(NSString *)path {
  NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
  NSNumber* defaultSize = [NSNumber numberWithLongLong:(2LL * 1024 * 1024 * 1024)];
  [attributes setObject:defaultSize forKey:NSFileSystemSize];
  [attributes setObject:defaultSize forKey:NSFileSystemFreeSize];
  [attributes setObject:defaultSize forKey:NSFileSystemNodes];
  [attributes setObject:defaultSize forKey:NSFileSystemFreeNodes];
  // TODO: NSFileSystemNumber? Or does fuse do that for us?
  // TODO: Should we have memset the statbuf to zero, or does fuse pre-fill values?
  
  // A subclass an override any of the above defaults by implementing the
  // fileSystemAttributesAtPath: selector and returning a custom dictionary.
  NSDictionary *customAttribs = [self fileSystemAttributesAtPath:path];
  if (customAttribs) {
    [attributes addEntriesFromDictionary:customAttribs];
  }
  
  // Maximum length of filenames
  // TODO: Create our own key so that a fileSystem can override this.
  stbuf->f_namemax = 255;
  
  // Block size
  // TODO: Create our own key so that a fileSystem can override this.
  stbuf->f_bsize = stbuf->f_frsize = 512;
  
  // Size in blocks
  NSNumber* size = [attributes objectForKey:NSFileSystemSize];
  assert(size);
  stbuf->f_blocks = [size longLongValue] / stbuf->f_frsize;
  
  // Number of free / available blocks
  NSNumber* freeSize = [attributes objectForKey:NSFileSystemFreeSize];
  assert(freeSize);
  stbuf->f_bfree = stbuf->f_bavail = [freeSize longLongValue] / stbuf->f_frsize;
  
  // Number of nodes
  NSNumber* numNodes = [attributes objectForKey:NSFileSystemNodes];
  assert(numNodes);
  stbuf->f_files = [numNodes longLongValue];
  
  // Number of free / available nodes
  NSNumber* freeNodes = [attributes objectForKey:NSFileSystemFreeNodes];
  assert(freeNodes);
  stbuf->f_ffree = stbuf->f_favail = [freeNodes longLongValue];
  
  return YES;
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory{
  *isDirectory = [path isEqualToString:@"/"];
  return YES; 
}

- (NSDictionary *)fileAttributesAtPath:(NSString *)path{
  return nil;
}


- (BOOL)fillStatBuffer:(struct stat *)stbuf forPath:(NSString *)path{
  NSString* dataPath = path;  // Default to the given path.
  
  BOOL isDirectory = NO;
  BOOL exists = [self fileExistsAtPath:dataPath isDirectory:&isDirectory];
  if (!exists) return NO;
  
  NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
  [attributes setObject:[NSNumber numberWithLong:0555] 
                 forKey:NSFilePosixPermissions];
  [attributes setObject:[NSNumber numberWithLong:(isDirectory ? 2 : 1)]
                 forKey:NSFileReferenceCount];
  [attributes setObject:(isDirectory ? NSFileTypeDirectory : NSFileTypeRegular)
                 forKey:NSFileType];
  
  // A subclass an override any of the above defaults by implementing the
  // fileAttributesAtPath: selector and returning a custom dictionary.
  NSDictionary *customAttribs = [self fileAttributesAtPath:dataPath];
  if (customAttribs) {
    [attributes addEntriesFromDictionary:customAttribs];
  }
  
  // Permissions (mode)
  NSNumber* perm = [attributes objectForKey:NSFilePosixPermissions];
  stbuf->st_mode = [perm longValue];
  NSString* fileType = [attributes objectForKey:NSFileType];
  if ([fileType isEqualToString:NSFileTypeDirectory ]) {
    stbuf->st_mode |= S_IFDIR;
  } else if ([fileType isEqualToString:NSFileTypeRegular]) {
    stbuf->st_mode |= S_IFREG;
  } else if ([fileType isEqualToString:NSFileTypeSymbolicLink]) {
    stbuf->st_mode |= S_IFLNK;
  } else {
    NSLog(@"Illegal file type: '%@' at path '%@'", fileType, path);
    return NO;
  }
  
  // Owner and Group
  // Note that if the owner or group IDs are not specified, the effective
  // user and group IDs for the current process are used as defaults.
  NSNumber* uid = [attributes objectForKey:NSFileOwnerAccountID];
  NSNumber* gid = [attributes objectForKey:NSFileGroupOwnerAccountID];
  stbuf->st_uid = uid ? [uid longValue] : geteuid();
  stbuf->st_gid = gid ? [gid longValue] : getegid();

  // nlink
  NSNumber* nlink = [attributes objectForKey:NSFileReferenceCount];
  stbuf->st_nlink = [nlink longValue];
      
  // TODO: For the timespec, there is a .tv_nsec (= nanosecond) part as well.
  // Since the NSDate returns a double, we can fill this in as well.

  // mtime, atime
  NSDate* mdate = [attributes objectForKey:NSFileModificationDate];
  if (mdate) {
    time_t t = (time_t) [mdate timeIntervalSince1970];
    stbuf->st_mtimespec.tv_sec = t;
    stbuf->st_atimespec.tv_sec = t;
  }

  // ctime  TODO: ctime is not "creation time" rather it's the last time the 
  // inode was changed.  mtime would probably be a closer approximation.
  NSDate* cdate = [attributes objectForKey:NSFileCreationDate];
  if (cdate) {
    stbuf->st_ctimespec.tv_sec = [cdate timeIntervalSince1970];
  }

  // Size for regular files.
  if (!isDirectory) {
    NSNumber* size = [attributes objectForKey:NSFileSize];
    if (size) {
      stbuf->st_size = [size longLongValue];
    } else {
      stbuf->st_size = 0;
    }
  }

  // Set the number of blocks used so that Finder will display size on disk 
  // properly.
  // TODO: The stat man page says that st_blocks is "actual number of blocks 
  // allocated for the file in 512-byte units".  Investigate whether this is a
  // man mis-print, since I suspect it should be the statvfs f_frsize? 
  if (stbuf->st_size > 0) {
    stbuf->st_blocks = stbuf->st_size / 512;
    if (stbuf->st_size % 512) {
      ++(stbuf->st_blocks);
    }
  }

  return YES;  
}

// #pragma mark Open/Close

- (id)openFileAtPath:(NSString *)path mode:(int)mode {
  return [manager contentsAtPath:path];
}

- (void)releaseFileAtPath:(NSString *)path handle:(id)handle {
}

// #pragma mark Reading

- (NSData *)contentsAtPath:(NSString *)path {
  return nil; 
}

- (NSString *)pathContentOfSymbolicLinkAtPath:(NSString *)path{
  return nil; 
}

- (NSArray *)directoryContentsAtPath:(NSString *)path {
  NSLog(@"directoryContentsAtPath must be implemented by a subclass");
  return nil;

}

// Directory contents with invisible resources added
- (NSArray *)fullDirectoryContentsAtPath:(NSString *)path {
  NSMutableArray *fullContents = [NSMutableArray array];
  [fullContents addObject:@"."];
  [fullContents addObject:@".."];
  
  
  NSArray *contents = [self directoryContentsAtPath:path];
  if (contents)
    [fullContents addObjectsFromArray:contents];
  
  return fullContents;
}

- (int)readFileAtPath:(NSString *)path handle:(id)handle
               buffer:(char *)buffer size:(size_t)size offset:(off_t)offset {
  NSData* data = handle;
  
  return [data getBytes:buffer size:size offset:offset];
}



// #pragma mark Writing

- (BOOL)createDirectoryAtPath:(NSString *)path attributes:(NSDictionary *)attributes {
  return NO;
}

#if 0  // TODO: Figure out a way to do this nicely :-)
- (BOOL)createFileAtPath:(NSString *)path contents:(NSData *)contents 
              attributes:(NSDictionary *)attributes {
  return NO;
}
#endif

- (BOOL)createSymbolicLinkAtPath:(NSString *)path pathContent:(NSString *)otherPath {
  return NO; 
}

- (BOOL)linkPath:(NSString *)source toPath:(NSString *)destination handler:(id)handler{
  return NO; 
}

- (BOOL)createFileAtPath:(NSString *)path attributes:(NSDictionary *)attributes {
  return NO;
}

- (int)writeFileAtPath:(NSString *)path handle:(id)handle 
                buffer:(const char *)buffer size:(size_t)size offset:(off_t)offset {
  return -EACCES;
}

- (BOOL)truncateFileAtPath:(NSString *)path offset:(off_t)offset {
  return NO;
}

- (BOOL)movePath:(NSString *)source toPath:(NSString *)destination handler:(id)handler {
  return NO;
}

- (BOOL)removeFileAtPath:(NSString *)path handler:(id)handler { 
  return NO;
}

// #pragma mark Finder



- (BOOL)shouldMountInFinder{
  return YES;
}

- (void)showInFinder {
  [[NSWorkspace sharedWorkspace] selectFile:[self mountPoint]
                   inFileViewerRootedAtPath:[[self mountPoint] stringByDeletingLastPathComponent]];

}




// #pragma mark Lifecycle



- (void)fuseInit {    
  isMounted_ = YES;
  [self fuseDidMount];
}

- (void)fuseDestroy {
  isMounted_ = NO;
    [self fuseDidUnmount];
  [[NSApplication sharedApplication] terminate:manager]; 
}

- (BOOL)shouldStartFuse {
  return YES;
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  if (![self shouldStartFuse]) return;
  [NSThread detachNewThreadSelector:@selector(startFuse) toTarget:self withObject:nil];
}

#if 0  // TODO: We should probably switch to just "open /".  
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
  NSLog(@"calling [self showInFinder]");
  if (isMounted_) {
    [self showInFinder];
  }
  return NO;
}
#endif

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
  [self stopFuse];
  return NSTerminateNow;
}

- (NSString *)mountName {
  NSString *mountName = [[[NSUserDefaults standardUserDefaults] stringForKey:@"FUSEMountName"] retain];
  if (!mountName) mountName = NSStringFromClass([self class]);
  return mountName;
}

- (NSString *)mountPoint {
  if (!mountPoint_) {
    mountPoint_ =  [[NSUserDefaults standardUserDefaults] stringForKey:@"FUSEMountPath"];
    // mountPoint_ = [mountPoint_ firstUnusedFilePath];
    [mountPoint_ retain];
  }
  return [[mountPoint_ copy] autorelease];
}

- (void)fuseWillMount {}
- (void)fuseDidMount {}

- (void)fuseWillUnmount{}
- (void)fuseDidUnmount{}





// #pragma mark -



static int fusefm_statfs(const char* path, struct statvfs* stbuf) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int res = 0;
  memset(stbuf, 0, sizeof(struct statvfs));
  if (![manager fillStatvfsBuffer:stbuf forPath:[NSString stringWithUTF8String:path]]) {
    res = -ENOENT;
  }
  [pool release];
  return res;
}

static int fusefm_getattr(const char *path, struct stat *stbuf) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int res = 0;
  memset(stbuf, 0, sizeof(struct stat));
  if (![manager fillStatBuffer:stbuf forPath:[NSString stringWithUTF8String:path]])
    res = -ENOENT;
  [pool release];
  return res;
}

static int fusefm_fgetattr(const char *path, struct stat *stbuf, struct fuse_file_info *fi) {
  // TODO: This is a quick hack to get fstat up and running.
  return fusefm_getattr(path, stbuf);
#if 0  
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int res = fusefm_getattr(path, stbuf);
  NSData *wrapper = (id)(int)fi->fh;
  
  if (wrapper) {
    stbuf->st_size = [wrapper length];
  }
    
  [pool release];
  return res;
#endif
}

static int fusefm_readdir(const char *path, void *buf, fuse_fill_dir_t filler,
                          off_t offset, struct fuse_file_info *fi)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int res = -ENOENT;
  
  NSArray *contents = [manager fullDirectoryContentsAtPath:[NSString stringWithUTF8String:path]];
  if (contents) {
    int i, count;
    res = 0;
    for (i = 0, count = [contents count]; i < count; i++) {
      filler(buf, [[contents objectAtIndex:i] UTF8String], NULL, 0);
    }
  }
  
  [pool release];
  return res;
}

static int fusefm_create(const char* path, mode_t mode, struct fuse_file_info* fi) {
  int res = -EACCES;
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
  NS_DURING
    if ([manager createFileAtPath:[NSString stringWithUTF8String:path]
                       attributes:nil]) {
      res = 0;
    }
  NS_HANDLER
  NS_ENDHANDLER
  [pool release];
  return res;
}

static int fusefm_open(const char *path, struct fuse_file_info *fi)
{
  int res = -ENOENT;
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NS_DURING
    id object = [manager openFileAtPath:[NSString stringWithUTF8String:path]
                                   mode:fi->flags];
    if (object != nil) {
      fi->fh = (uint64_t)(int)[object retain];
      res = 0;
    }
  NS_HANDLER
  NS_ENDHANDLER
  [pool release];
  return res;
}


static int fusefm_release(const char *path, struct fuse_file_info *fi) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  id object = (id)(int)fi->fh;
  [manager releaseFileAtPath:[NSString stringWithUTF8String:path] handle:object];
  if (object) {
    [object release]; 
  }
  [pool release];
  return 0;
}

static int fusefm_truncate(const char* path, off_t offset) {
  int res = -EACCES;
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

  if ([manager truncateFileAtPath:[NSString stringWithUTF8String:path]
                           offset:offset]) {
    res = 0;
  }
  
  [pool release];
  return res;
}

static int fusefm_ftruncate(const char* path, off_t offset, struct fuse_file_info *fh) {
  return fusefm_truncate(path, offset);
}

static int fusefm_chown(const char* path, uid_t uid, gid_t gid) {
  return 0;  // Always succeed for now.
}
static int fusefm_chmod(const char* path, mode_t mode) {
  return 0;  // Always succeed for now.
}

static int fusefm_write(const char* path, const char* buf, size_t size, 
                        off_t offset, struct fuse_file_info* fi) {
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

  int length = [manager writeFileAtPath:[NSString stringWithUTF8String:path]
                                 handle:(id)(int)fi->fh
                                 buffer:buf
                                   size:size
                                 offset:offset];

  [pool release];
  return length;
}

static int fusefm_read(const char *path, char *buf, size_t size, off_t offset,
                       struct fuse_file_info *fi) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  int length = [manager readFileAtPath:[NSString stringWithUTF8String:path]
                                handle:(id)(int)fi->fh
                                buffer:buf
                                  size:size
                                offset:offset];
  [pool release];
  return length;
}

static int fusefm_readlink(const char *path, char *buf, size_t size)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSString *pathContent = [manager pathContentOfSymbolicLinkAtPath:[NSString stringWithUTF8String:path]];
  [pathContent getFileSystemRepresentation:buf maxLength:size];
  [pool release];
  return 0;
}

static int fusefm_getxattr(const char *path, const char *name, char *value,
                           size_t size) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int res = -ENOENT;  // TODO: How to return error here?
#if 0
  NS_DURING
    NSData *data = [manager valueOfExtendedAttribute:[NSString stringWithUTF8String:name]
                                             forPath:[NSString stringWithUTF8String:path]];
    res = [data length];  // default to returning size of buffer.
    if (value) {
      if (size > [data length]) {
        size = [data length];
      }
      [data getBytes:&value length:size];
      res = size;  // bytes read
    }
  NS_HANDLER
  NS_ENDHANDLER
#endif
  [pool release];
  return res;
  //  int res = getxattr(path, name, value, size, 0, 0);
  //
  //  if (res == -1)
  //    return -errno;
  //  return res;
}

static int fusefm_listxattr(const char *path, char *list, size_t size)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
 
  int res = -ENOENT;
#if 0
  NS_DURING
    NSArray *attributeNames = [manager extendedAttributesForPath: [NSString stringWithUTF8String:path]];
    char zero = 0;
    NSMutableData *data = [NSMutableData dataWithCapacity:size];  
    for (int i = 0, count = [attributeNames count]; i < count; i++) {
      [data appendData:[[attributeNames objectAtIndex:i] dataUsingEncoding:NSUTF8StringEncoding]];
      [data appendBytes:&zero length:1];
    }
    res = [data length];  // default to returning size of buffer.
    if (list) {
      if (size > [data length]) {
        size = [data length];
      }
      [data getBytes:list length:size];
      res = size;
    }
  NS_HANDLER
  NS_ENDHANDLER
#endif
  [pool release];
  return res;
  //  int res = listxattr(path, list, size, 0);
  //
  //  if (res == -1)
  //    return  -errno;
  //  return res;
}

static int fusefm_rename(const char* path, const char* toPath) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int ret = -EACCES;
  
  NSString* source = [NSString stringWithUTF8String:path];
  NSString* destination = [NSString stringWithUTF8String:toPath];
  if ([manager movePath:source toPath:destination handler:nil]) {
    ret = 0;  // Success!
  }
  [pool release];
  return ret;
  
}

static int fusefm_mkdir(const char* path, mode_t mode) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int ret = -EACCES;

  // TODO: Create proper attributes dictionary from mode_t.
  if ([manager createDirectoryAtPath:[NSString stringWithUTF8String:path] 
                          attributes:nil]) {
    ret = 0;  // Success!
  }
  [pool release];
  return ret;
}

static int fusefm_unlink(const char* path) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int ret = -EACCES;
  
  if ([manager removeFileAtPath:[NSString stringWithUTF8String:path] 
                        handler:nil]) {
    ret = 0;  // Success!
  }
  [pool release];
  return ret;
}

static int fusefm_rmdir(const char* path) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int ret = -EACCES;
  
  if ([manager removeFileAtPath:[NSString stringWithUTF8String:path] 
                        handler:nil]) {
    ret = 0;  // Success!
  }
  [pool release];
  return ret;
}

static void *fusefm_init(struct fuse_conn_info *conn){
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // We'll hold onto manager for the mount lifetime.
  [manager retain];
  [manager fuseInit];

  [pool release];
  return manager;
}


static void fusefm_destroy(void *private_data){
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
  [manager fuseDestroy];
  
  // Release the manager
  [(id)private_data release];

  [pool release];
}

static struct fuse_operations fusefm_oper = {
  .init = fusefm_init,
  .destroy = fusefm_destroy,
  .statfs = fusefm_statfs,
  .getattr	= fusefm_getattr,
  .fgetattr = fusefm_fgetattr,
  // .setattr	= fusefm_setattr,
  .readdir	= fusefm_readdir,
  .open	= fusefm_open,
  .release	= fusefm_release,
  .read	= fusefm_read,
  .readlink	= fusefm_readlink,
  .write = fusefm_write,
  .create = fusefm_create,
  //.getxattr	= fusefm_getxattr,
  //.listxattr	= fusefm_listxattr,
  .mkdir = fusefm_mkdir,
  .unlink = fusefm_unlink,
  .rmdir = fusefm_rmdir,
  .rename = fusefm_rename,
  .truncate = fusefm_truncate,
  .ftruncate = fusefm_ftruncate,
  .chown = fusefm_chown,
  .chmod = fusefm_chmod,
};

int fusefm_setattr(const char *path, const char *a,
                   const char *b, size_t c, 
                   int d)
{
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
  // TODO: Body :-)
  [pool release];  
  return 0;
}

- (void)startFuse {
  assert([NSThread isMultiThreaded]);
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSString *mountPath = [self mountPoint];
  
  if (![mountPath length]){
    NSLog(@"No mount point specified");
    [pool release];
    return;
  } else {
    NSLog(@"mounting on: %@", mountPath);
  }
  
  // Create mount path
  NSFileManager *fileManager = [NSFileManager defaultManager];
  [fileManager createDirectoryAtPath:mountPath attributes:nil];
  
  
  NSMutableArray *arguments = [NSMutableArray arrayWithObjects:
    [[NSBundle mainBundle] executablePath],
#if 0
    [NSString stringWithFormat:@"-ovolname=%@",[self mountName]],
#endif
    @"-f",  // Foreground rather than daemonize
    @"-s",  // Single-threaded until we can work out threading issues.
    nil];
  [arguments addObject:mountPath];
  
  // Start Fuse Main
  const char *argv[[arguments count]];
  int i, count;

  for (i = 0, count = [arguments count]; i < count; i++) {
    argv[i] = [[arguments objectAtIndex:i] copyUTF8String];
  }
  
  argv[0] = strcpy(malloc(strlen(argv[0]+1)), argv[0]);
  
  int argc = sizeof(argv) / sizeof(argv[0]);
  [self fuseWillMount];
  [pool release];
  fuse_main(argc, (char **)argv, &fusefm_oper, self); 
}

- (void)stopFuse {
  
  // Remove volume header file
  NSFileManager *fileManager = [NSFileManager defaultManager];
  [fileManager removeFileAtPath:[self mountPoint] handler:nil];
  [self fuseWillUnmount];
  // Unmount
  NSTask *unmountTask = [NSTask launchedTaskWithLaunchPath:@"/sbin/umount" arguments:[NSArray arrayWithObjects: @"-v", [self mountPoint], nil]];
  [unmountTask waitUntilExit];
}




@end

