/*
  Copyright (c) 2007-2010, Marcus Müller <znek@mulle-kybernetik.com>.
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

#import "Watchdog.h"
#import <unistd.h>
#import <fcntl.h>
#import <sys/event.h>
#import "iTunesLibrary.h"

@interface Watchdog (Private)

- (void)watchPaths:(NSArray *)_paths ofClient:(id)_client;
- (void)watchPath:(NSString *)_path ofClient:(id)_client;
- (void)forgetPaths:(NSArray *)_paths;
- (void)forgetPath:(NSString *)_path;

- (id)clientForPath:(NSString *)_path;

- (void)receiveMessage:(NSDictionary *)_ui;
@end

@implementation Watchdog

NSString *WatchdogPathKey  = @"WatchdogPath";
NSString *WatchdogFlagsKey = @"WatchdogFlags";

+ (id)sharedWatchdog {
  static id sharedInstance = nil;
  if (!sharedInstance) {
    sharedInstance = [[self alloc] init];
  }
  return sharedInstance;
}

- (id)init {
  self = [super init];
  if (self) {
    self->kqueueHandle = kqueue();
    if (self->kqueueHandle == -1 ) {
      [self release];
      return nil;
    }
    
    self->paths   = [[NSMutableArray alloc] init];
    self->fds     = [[NSMutableArray alloc] init];
    self->clients = [[NSMutableArray alloc] init];
    [NSThread detachNewThreadSelector:@selector(run:)
              toTarget:self
              withObject:self];
  }
  return self;
}

- (void)dealloc {
  if (self->kqueueHandle != -1) {
    int fd = self->kqueueHandle;
    self->kqueueHandle = -1;
    close(fd);
  }
  [self->paths   release];
  [self->fds     release];
  [self->clients release];
  [super dealloc];
}

/* Public API */

- (void)watchLibrary:(iTunesLibrary *)_lib {
  [self watchPath:[_lib libraryPath] ofClient:_lib];
}

- (void)forgetLibrary:(iTunesLibrary *)_lib {
  [self forgetPath:[_lib libraryPath]];
}

/* Private API */

- (void)watchPaths:(NSArray *)_paths ofClient:(id)_client {
  unsigned count, i;
  
  for (i = 0, count = [_paths count]; i < count; i++)
    [self watchPath:[_paths objectAtIndex:i] ofClient:_client];
}

- (void)watchPath:(NSString *)_path ofClient:(id)_client {
  struct kevent   e;
  struct timespec timeout;
  int fd;
  
  bzero(&timeout, sizeof(timeout));
  fd = open([_path fileSystemRepresentation], O_RDONLY, 0);
  if (fd > 0) {
    EV_SET(&e,
           fd,
           EVFILT_VNODE,
           EV_ADD | EV_ENABLE | EV_CLEAR,
           NOTE_WRITE | NOTE_DELETE,
           (intptr_t)NULL,
           (void *)_path);
    [self->paths   addObject:_path];
    [self->fds     addObject:[NSNumber numberWithInt:fd]];
    [self->clients addObject:_client];
  }
  kevent(self->kqueueHandle, &e, 1, NULL, 0, &timeout);
}

- (void)forgetPaths:(NSArray *)_paths {
  unsigned count, i;
  
  for (i = 0, count = [_paths count]; i < count; i++)
    [self forgetPath:[_paths objectAtIndex:i]];
}

- (void)forgetPath:(NSString *)_path {
  NSUInteger idx;
  NSInteger  fd;

  idx = [self->paths indexOfObject:_path];
  if (idx == NSNotFound) return;

  fd = [[self->fds objectAtIndex:idx] intValue];
  close(fd);

  [self->fds     removeObjectAtIndex:idx];
  [self->paths   removeObjectAtIndex:idx];
  [self->clients removeObjectAtIndex:idx];
}

- (id)clientForPath:(NSString *)_path {
  NSUInteger idx;
  
  idx = [self->paths indexOfObject:_path];
  if (idx == NSNotFound) return nil;
  return [self->clients objectAtIndex:idx];
}

- (void)run:(id)_sender {
  struct kevent e;
  int n;
  
  while (self->kqueueHandle != -1 ) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    n = kevent(self->kqueueHandle, NULL, 0, &e, 1, NULL);
    if (n > 0) {
      if (e.filter == EVFILT_VNODE && e.fflags) {
        NSMutableDictionary *ui;
        NSString            *path;
        
        path = (NSString *)e.udata;
        ui   = [[NSMutableDictionary alloc] initWithCapacity:2];
        [ui setObject:[NSNumber numberWithUnsignedInt:e.fflags]
            forKey:WatchdogFlagsKey];
        [ui setObject:path forKey:WatchdogPathKey];
        [self performSelectorOnMainThread:@selector(receiveMessage:)
              withObject:ui
              waitUntilDone:YES];
        [ui release];
      }
    }
    [pool release];
  }
}

- (void)receiveMessage:(NSDictionary *)_ui {
  NSString *path;
  NSNumber *flags;
  unsigned fflags;
  id       client;

  [_ui retain];

  path   = [_ui objectForKey:WatchdogPathKey];
  flags  = [_ui objectForKey:WatchdogFlagsKey];
  fflags = [flags unsignedIntValue];
  client = [self clientForPath:path];

  if ((fflags & NOTE_WRITE) == NOTE_WRITE) {
    [client reload];
  }
  else if ((fflags & NOTE_DELETE) == NOTE_DELETE) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
      /* some process did an atomic write which qualifies as file change.
       * because the original file was removed, we need to re-assign
       * for the file in question
       */
      [self forgetPath:path];
      [self watchPath:path ofClient:client];
      [client reload];
    }
    else {
      [client reload];
    }
  }
  else {
    NSLog(@"WTF?!"); // can't happen
  }
  [_ui release];
}

@end
