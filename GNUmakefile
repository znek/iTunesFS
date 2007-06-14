# iTunesFS.app

include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DOMAIN = LOCAL

APP_NAME = iTunesFS

iTunesFS_PRINCIPAL_CLASS  = NSApplication
iTunesFS_APPLICATION_ICON = iTunesFS.tiff
iTunesFS_MAIN_MODEL_FILE  = MainMenu.gorm
iTunesFS_LANGUAGES        = English German French Italian Spanish Japanese
iTunesFS_SUBPROJECTS      = FUSEObjC-GNUstep

iTunesFS_OBJC_PRECOMPILED_HEADERS = common.h

iTunesFS_OBJC_FILES +=				\
	iTunesFileSystem.m			\
						\
	iTunesLibrary.m				\
	iPodLibrary.m				\
	iTunesPlaylist.m			\
	iTunesTrack.m				\
						\
	Watchdog.m				\
						\
	NSObject+Extensions.m			\
	NSString+Extensions.m			\
	NSArray+Extensions.m			\
	NSURL+Extensions.m			\

iTunesFS_LOCALIZED_RESOURCE_FILES +=		\
	MainMenu.gorm				\
	Localizable.strings			\

iTunesFS_RESOURCE_FILES +=			\
	iTunesFS.tiff				\


-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/application.make
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include GNUmakefile.postamble
