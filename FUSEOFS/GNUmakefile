# FUSEOFS

include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = FUSEOFS

FUSEOFS_INCLUDE_DIRS +=			\
	-I../FUSEObjC-GNUstep		\

FUSEOFS_OBJC_FILES +=			\
	FUSEObjectFileSystem.m		\
	NSObject+FUSEOFS.m		\
	FUSEOFSFileProxy.m		\

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
