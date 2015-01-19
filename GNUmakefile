# iTunesFS.app

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif

ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

include $(GNUSTEP_MAKEFILES)/common.make


GNUSTEP_INSTALLATION_DOMAIN = LOCAL

APP_NAME = iTunesFS

iTunesFS_PRINCIPAL_CLASS  = NSApplication
iTunesFS_APPLICATION_ICON = iTunesFS.tiff
iTunesFS_MAIN_MODEL_FILE  = MainMenu.gorm
iTunesFS_LANGUAGES        = English German French Italian Spanish Japanese
iTunesFS_SUBPROJECTS      = FUSEOFS

iTunesFS_OBJC_PRECOMPILED_HEADERS = common.h

ADDITIONAL_CPPFLAGS     += -std=c99
ADDITIONAL_INCLUDE_DIRS += -IFUSEOFS -IFUSEOFS/GSFUSE
ADDITIONAL_GUI_LIBS     += -lfuse -lz


GNUSTEP_HOST_OS := $(shell gnustep-config --variable=GNUSTEP_HOST_OS 2>/dev/null)

ifneq ($(FOUNDATION_LIB),apple)
ADDITIONAL_CPPFLAGS += -DNO_OSX_ADDITIONS
endif

ifeq ($(GNUSTEP_HOST_OS),linux-gnu)
ADDITIONAL_CPPFLAGS += -DNO_WATCHDOG
endif

ifeq ($(FOUNDATION_LIB),apple)
iTunesFS_INCLUDE_DIRS  += -Ifilesystems-objc-support
ADDITIONAL_NATIVE_LIBS += OSXFUSE Accelerate
endif

iTunesFS_OBJC_FILES +=				\
	main.m					\
						\
	iTunesFileSystem.m			\
						\
	iTunesLibrary.m				\
	iPodLibrary.m				\
	JBiPodLibrary.m				\
	iTunesPlaylist.m			\
	iTunesM3UPlaylist.m			\
	iTunesTrack.m				\
	iTunesFormatFile.m			\
	iTunesFSFormatter.m			\
						\
	StreamReader.m				\
	NSString+Extensions.m			\
	NSURL+Extensions.m			\
	NSData+ZlibDecompression.m		\

ifeq ($(FOUNDATION_LIB),apple)
iTunesFS_OBJC_FILES +=				\
	filesystems-objc-support/NSImage+IconData.m
endif

ifneq ($(GNUSTEP_HOST_OS),linux-gnu)
iTunesFS_OBJC_FILES +=				\
	Watchdog.m
endif

iTunesFS_LOCALIZED_RESOURCE_FILES +=		\
	MainMenu.gorm				\
	Localizable.strings			\
	AlbumsTrackFormat.txt			\
	PlaylistsTrackFormat.txt		\

iTunesFS_RESOURCE_FILES +=			\
	iTunesFS.tiff				\


-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/application.make
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include GNUmakefile.postamble
