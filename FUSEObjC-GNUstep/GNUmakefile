# FUSEObjC-GNUstep

include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = FUSEObjC-GNUstep

FUSEObjC-GNUstep_CPPFLAGS +=		\
	-D_FILE_OFFSET_BITS=64		\

FUSEObjC-GNUstep_OBJC_FILES +=		\
	FUSEMain.m			\
	FUSEFileSystem.m		\

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
