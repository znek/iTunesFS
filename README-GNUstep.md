About the GNUstep port
======================

This port was done using a recent (2011-01-25) svn trunk revision of
[GNUstep](http://www.gnustep.org/), utilizing gnustep-make 2.4.0.

The system used for the port is running FreeBSD 8.2-RC3,
which has a native kqueue() implementation.

I used the fusefs-libs BSD port from the ports collection, fusefs-libs-2.7.4.

It's probably a good idea to include autoconf magic for figuring out all
compile time requirements, but for the time being it's just not here.


FUSEOFS/GSFUSE
==============

This is a fork of sdk-objc from MacFUSE which allows conditional compilation
of Mac OS X "extensions" (HFS+ and Finder related methods).
The GNUstep Makefile currently drops all MacFUSE-only functionality when the
used Foundation framework/library isn't the Apple implementation.

I'm still a bit undecided whether to base the Mac OS X version on this fork,
but at the moment this just hasn't happened and probably won't in the near
future.


PROBLEMS
========

- The AppKit requirement isn't something I'm too happy with, I'd prefer to
  have a tool instead (similar to sshfs and the like).

- On FreeBSD 8.2rc3 I needed to grant permissions for `/dev/fuse0`:
```
root@fbsd8:~ # chmod o+rw /dev/fuse0
```

- On FreeBSD 10.x I need to do the following:
```
root@fbsd10:~ # cat << EOF >> /etc.fuse.conf
user_allow_other
EOF
root@fbsd10:~ # cat << EOF >> /etc/devfs.conf
own     fuse    root:operator
perm    fuse    0666
EOF
root@fbsd10:~ # cat << EOF >> /etc/sysctl.conf
vfs.usermount=1
EOF
root@fbsd10:~ # sysctl vfs.usermount=1
```

EXAMPLE
=======

There's a tiny, handcrafted (in all senses ;-) version of an iTunes Music
Library XML file in the "examples" folder. After you have built the
iTunesFS.app, use this command in a shell for starting the file system:

```
$ openapp ./iTunesFS.app -Library /tmp/iTunesMusicLibrary.xml \
						 -iTunesFileSystemDebugEnabled YES
```

You will then be able to browse the iTunes library, i.e.:

```
$ ls -l /tmp/iTunesFS/
total 0
dr-xr-xr-x  2 znek  wheel  0 Jan  1  1970 Albums
dr-xr-xr-x  2 znek  wheel  0 Jan  1  1970 Artists
dr-xr-xr-x  2 znek  wheel  0 Jan  1  1970 Playlists
$ ls -l /tmp/iTunesFS/Playlists
total 0
dr-xr-xr-x  2 znek  wheel  0 Jan  1  1970 Audiobooks
dr-xr-xr-x  2 znek  wheel  0 Jan  1  1970 Faves
dr-xr-xr-x  2 znek  wheel  0 Jan  1  1970 Instrumental
dr-xr-xr-x  2 znek  wheel  0 Jan  1  1970 Library
dr-xr-xr-x  2 znek  wheel  0 Jan  1  1970 Movies
dr-xr-xr-x  2 znek  wheel  0 Jan  1  1970 Music
dr-xr-xr-x  2 znek  wheel  0 Jan  1  1970 Party Shuffle
dr-xr-xr-x  2 znek  wheel  0 Jan  1  1970 Podcasts
dr-xr-xr-x  2 znek  wheel  0 Jan  1  1970 TV Shows
$ ls -l /tmp/iTunesFS/Playlists/Faves/
total 10919
-r-xr-xr-x  1 znek  wheel  4082013 Mar 27  2006 001 Karma.m4a
-r-xr-xr-x  1 znek  wheel  7098527 Jun 14 18:43 002 ChoCo FrigHTs.mp3
$ ls -l /tmp/iTunesFS/Artists/Moshcircus/Karma/
total 39551
-r-xr-xr-x  1 znek  wheel  4450130 Mar 27  2006 Diabolic Infernal Satan.m4a
-r-xr-xr-x  1 znek  wheel  4649112 Mar 27  2006 Enola Gay.m4a
-r-xr-xr-x  1 znek  wheel  3624537 Mar 27  2006 Flesh of Gods.m4a
-r-xr-xr-x  1 znek  wheel  5292322 Mar 27  2006 Into Light.m4a
-r-xr-xr-x  1 znek  wheel  4082013 Mar 27  2006 Karma.m4a
-r-xr-xr-x  1 znek  wheel  4806113 Mar 27  2006 Online with God.m4a
-r-xr-xr-x  1 znek  wheel  5651675 Mar 27  2006 Per Aspera Ad Astra.m4a
-r-xr-xr-x  1 znek  wheel   963599 Mar 27  2006 Salvation One.m4a
-r-xr-xr-x  1 znek  wheel  1454902 Mar 27  2006 Salvation Three.m4a
-r-xr-xr-x  1 znek  wheel  1918854 Mar 27  2006 Salvation Two.m4a
-r-xr-xr-x  1 znek  wheel  3604444 Mar 27  2006 Samsara.m4a
```
