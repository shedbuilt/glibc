#!/bin/bash
patch -Np1 -i $SHED_PATCHDIR/glibc-2.26-fhs-1.patch
GCC_INCDIR=/usr/lib/gcc/$(gcc -dumpmachine)/7.2.0/include
mkdir -v build
cd build
CC="gcc -isystem $GCC_INCDIR -isystem /usr/include" \
../configure --prefix=/usr                          \
             --disable-werror                       \
             --enable-kernel=3.2                    \
             --enable-stack-protector=strong        \
             libc_cv_slibdir=/lib
unset GCC_INCDIR
make -j 4
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make DESTDIR=$SHED_FAKEROOT install
install -v -Dm644 ../nscd/nscd.conf $SHED_FAKEROOT/etc/nscd.conf
install -v -Dm644 ../nscd/nscd.tmpfiles $SHED_FAKEROOT/usr/lib/tmpfiles.d/nscd.conf
install -v -Dm644 ../nscd/nscd.service $SHED_FAKEROOT/lib/systemd/system/nscd.service
