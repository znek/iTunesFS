About the OSX / macOS port
==========================

History
-------

iTunesFS has come a long way since its first inception in 2007.
It linked against MacFUSE and was developed on a G5
[Power Mac](https://en.wikipedia.org/wiki/Power_Macintosh) running OSX 10.4.x
using Xcode 2.x in a couple of days.
Later, I got an Intel Mac and subsequently added Intel support to iTunesFS.
In the meantime, MacFUSE was abandoned and other projects took over, with
[macFUSE](http://osxfuse.github.com/) (then called *OSXFUSE*) prevailing.
Also, Apple dropped the PowerPC platform and recent Xcode versions lost their
backwards compatibility for older SDKs (usually only supporting the previous
platform SDK). At the time of writing (September 2016) Xcode 8 and macOS 10.12
were just released - and iTunesFS still has backwards compatibility up to
OSX 10.5/PowerPC!


Prerequisites
=============

macFUSE
-------

You have to install [macFUSE](http://osxfuse.github.com/).
macFUSE provides a framework and headers that iTunesFS uses.

Xcode
-----

You need to get a recent Xcode from
[Apple's developer site](https://developer.apple.com/xcode/) in order to compile
iTunesFS on OSX / macOS.
There are 2 shared schemes for building iTunesFS, `Debug` and `Release`.
Both schemes are based on their respective
[xcconfig](https://pewpewthespells.com/blog/xcconfig_guide.html)
files [debug](xcconfig/debug.xcconfig) and [release](xcconfig/release.xcconfig)
which both include a common [base](xcconfig/base.xcconfig).

- `Debug` will build a debug version for the current SDK and architecture, only.
  This will work out of the box on all machines (tell me if it doesn't!)
- `Release` will build a release version for several SDKs (including SDKs you
  won't have on your machine!) and `i386` and `ppc` architectures
  (the latter your Xcode won't probably support!)

In order to *fix* `Release` you have _two_ options:

- edit [release.xcconfig](xcconfig/release.xcconfig) and add
  `VALID_ARCHS = $(NATIVE_ARCH_ACTUAL)` and `ARCHS = $(NATIVE_ARCH_ACTUAL)`
  anywhere. Of course you can also provide any other value which will work in
  your development environment.
- modify Xcode to provide backwards compatibility for old SDKs, compilers and
  linkers. That's what I have done myself, but I can't release such a project
  publicly due to the SDKs and old binaries being copyrighted by Apple.


References
==========

- [Xcode](https://developer.apple.com/xcode/)
- [macFUSE (current version, renamed from OSXFUSE)](http://osxfuse.github.com/)
- [MacFUSE (original version, archived)](https://code.google.com/archive/p/macfuse/)
