#!/bin/sh


SOURCE_DIR=${0%/*}
BIN_DIR=~/Applications/iTunesFS.app
DST_DIR=/tmp/iTunesFS.$$
DST_IMG=${DST_DIR}.dmg

. ${SOURCE_DIR}/Version
RELEASE=${MAJOR_VERSION}.${MINOR_VERSION}.${SUBMINOR_VERSION}

if [ "$#" = "1" ]; then
  RELEASE=$1
fi

echo "Making release: $RELEASE"

CFBundleShortVersionString=`defaults read "${BIN_DIR}/Contents/Info" CFBundleShortVersionString`

if [ "$RELEASE" != "$CFBundleShortVersionString" ]; then
  echo "[ERROR] CFBundleShortVersionString in ${BIN_DIR}/Contents/Info.plist is ${CFBundleShortVersionString}, SHOULD BE ${RELEASE}!"
  exit 1
fi

mkdir $DST_DIR
if [ ! -d $DST_DIR ]; then
  echo "Couldn't create intermediary dir $DST_DIR"
  exit 1
fi

# copy binaries
pushd $BIN_DIR/.. > /dev/null
gnutar cf - ${BIN_DIR##*/} | ( cd $DST_DIR ; gnutar xf - )
popd > /dev/null

# copy READMEs
cd $SOURCE_DIR
gnutar cf - README AUTHORS COPYING COPYRIGHT | ( cd $DST_DIR; gnutar xf - )

# remove extra garbage
cd $DST_DIR
# some build artifact
rm -f iTunesFS.app/iTunesFS.app
find . -type d -name .svn -exec rm -rf {} \; > /dev/null 2>&1

# compute size for .dmg
SIZE_KB=`du -sk ${DST_DIR} | awk '{print $1}'`
# add some extra
SIZE_KB=`expr $SIZE_KB + 4096`

hdiutil create -size ${SIZE_KB}k ${DST_IMG} -layout NONE
#hdiutil create -size 15m ${DST_IMG} -layout NONE
DISK=`hdid -nomount ${DST_IMG} | awk '{print $1}'`
VOLUME_NAME="iTunesFS ${RELEASE}"
newfs_hfs -v "${VOLUME_NAME}" $DISK
hdiutil eject ${DISK}
DISK=`hdid ${DST_IMG} | awk '{print $1}'`

#copy package to .dmg
gnutar cf - . | ( cd "/Volumes/${VOLUME_NAME}" ; gnutar xf - )

# once again eject, to synchronize
hdiutil eject ${DISK}

# convert temp .dmg into compressed read-only distribution version
REL_IMG="${DST_DIR%%.*}-${RELEASE}.dmg"

# remove eventual ancestor
rm -f ${REL_IMG}

# convert .dmg into read-only zlib (-9) compressed release version
hdiutil convert -format UDZO ${DST_IMG} -o ${REL_IMG} -imagekey zlib-level=9

# internet-enable the release .dmg. for details see
# http://developer.apple.com/ue/files/iedi.html
hdiutil internet-enable -yes ${REL_IMG}

# clean up
rm -rf ${DST_DIR}
rm -rf ${DST_IMG}

MD5SUM=`md5 -q ${REL_IMG}`
REL_IMG_SIZE_B=`ls -l ${REL_IMG} | awk '{print $5}'`

echo "Image ready at: ${REL_IMG}"
echo "=== MAINTAINER UPLOAD ==="
echo "scp ${REL_IMG} ftp.mulle-kybernetik.com:~ftp/pub/software/iTunesFS/"
echo "=== DOWNLOAD URLS ==="
echo "http://www.mulle-kybernetik.com/software/iTunesFS/downloads/${REL_IMG##*/}"
echo "ftp://ftp.mulle-kybernetik.com/pub/software/iTunesFS/${REL_IMG##*/}"
echo "=== RSS FEED ==="
echo "<enclosure sparkle:md5Sum=\"${MD5SUM}\" url=\"http://www.mulle-kybernetik.com/software/iTunesFS/downloads/${REL_IMG##*/}\" length=\"${REL_IMG_SIZE_B}\" type=\"application/octet-stream\"/>"
