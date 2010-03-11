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

#import "iTunesFSController.h"
#import "common.h"
#import "iTunesFileSystem.h"

@implementation iTunesFSController

- (void)awakeFromNib {
	NSDictionary *defaults = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSUserDefaults"];
	if (defaults)
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)applicationDidFinishLaunching:(NSNotification *)_notif {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
		selector:@selector(didMount:)
		name:kGMUserFileSystemDidMount
		object:nil];
	[nc addObserver:self
		selector:@selector(didUnmount:)
		name:kGMUserFileSystemDidUnmount
		object:nil];

  NSUserDefaults *ud   = [NSUserDefaults standardUserDefaults];
  NSString       *path = [ud stringForKey:@"FUSEMountPath"];
  self->fs = [[iTunesFileSystem alloc] init];
  [self->fs mountAtPath:path];
}

- (void)didMount:(NSNotification *)_notif {
	NSUserDefaults *ud    = [NSUserDefaults standardUserDefaults];
	BOOL autoOpenInFinder = [ud boolForKey:@"AutoOpenInFinder"];
	if (autoOpenInFinder) {
		NSString *path = [[_notif userInfo]
						          objectForKey:kGMUserFileSystemMountPathKey];
		[[NSWorkspace sharedWorkspace]
		              selectFile:path
					  inFileViewerRootedAtPath:[path stringByDeletingLastPathComponent]];
	}
}

- (void)didUnmount:(NSNotification *)_notif {
	[[NSApplication sharedApplication] terminate:nil];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)_sender {
  [self->fs unmount];
  [self->fs release];
  return NSTerminateNow;
}

@end
