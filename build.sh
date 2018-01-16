#!/bin/bash

shed_glibc_cleanup ()
{
    # HACK: Move back /usr/include/limits.h following compilation
    if [ -e /usr/include/limits.h.bak ]; then
        mv /usr/include/limits.h.bak /usr/include/limits.h
    fi
}

# If /usr/include/limits.h is present when building, make enters an infinite loop in glibc 2.26
# HACK: For now, temporarily move the installed /usr/include/limits.h aside when compiling
if [ -e /usr/include/limits.h ]; then
    mv /usr/include/limits.h /usr/include/limits.h.bak
fi

# Patch
patch -Np1 -i "${SHED_PATCHDIR}/glibc-2.26-fhs-1.patch"
patch -Np1 -i "${SHED_PATCHDIR}/glibc-2.26-local_glob_exploits-2.patch"

# Configure
mkdir -v build
cd build
case "$SHED_BUILDMODE" in
    toolchain)
        ../configure --prefix=/tools                    \
                     --host=$SHED_TOOLCHAIN_TARGET      \
                     --build=$(../scripts/config.guess) \
                     --enable-kernel=3.2                \
                     --with-headers=/tools/include      \
                     libc_cv_forced_unwind=yes          \
                     libc_cv_c_cleanup=yes || { shed_glibc_cleanup; exit 1; }
        ;;
    bootstrap)
        # Avoid references to the temporary /tools directory
        ln -sfv /tools/lib/gcc /usr/lib
        ;&
    *)
        GCC_INCDIR=/usr/lib/gcc/$(gcc -dumpmachine)/7.2.0/include
        CC="gcc -isystem $GCC_INCDIR -isystem /usr/include" \
        ../configure --prefix=/usr                          \
                     --disable-werror                       \
                     --enable-kernel=3.2                    \
                     --enable-stack-protector=strong        \
                     libc_cv_slibdir=/lib || { shed_glibc_cleanup; exit 1; }
        unset GCC_INCDIR
        ;;
esac

# Build
make -j $SHED_NUMJOBS || { shed_glibc_cleanup; exit 1; }
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make DESTDIR="$SHED_FAKEROOT" install || { shed_glibc_cleanup; exit 1; }
shed_glibc_cleanup

case "$SHED_BUILDMODE" in
    bootstrap|release)
        # Install ncsd config files
        install -v -Dm644 ../nscd/nscd.conf "${SHED_FAKEROOT}/etc/nscd.conf"
        install -v -Dm644 ../nscd/nscd.tmpfiles "${SHED_FAKEROOT}/usr/lib/tmpfiles.d/nscd.conf"
        install -v -Dm644 ../nscd/nscd.service "${SHED_FAKEROOT}/lib/systemd/system/nscd.service"
        mkdir -pv "${SHED_FAKEROOT}/var/cache/nscd"
        mkdir -pv "${SHED_FAKEROOT}/usr/lib/locale"
        mkdir -v "${SHED_FAKEROOT}/etc"

        # Install other default config files
        install -v -m644 "${SHED_CONTRIBDIR}/nsswitch.conf" "${SHED_FAKEROOT}/etc/nsswitch.default"
        install -v -m644 "${SHED_CONTRIBDIR}/ld.so.conf" "${SHED_FAKEROOT}/etc/ld.so.default"
        mkdir -pv "${SHED_FAKEROOT}/etc/ld.so.conf.d"
        ;&
    *)
        # Compatibility symlink for non ld-linux-armhf awareness
        ln -sv ld-2.26.so "${SHED_FAKEROOT}/lib/ld-linux.so.3"
        ;;
esac