#!/bin/bash
shed_glibc_cleanup ()
{
    # HACK: Move back /usr/include/limits.h following compilation
    if [ -e /usr/include/limits.h.bak ]; then
        mv /usr/include/limits.h.bak /usr/include/limits.h
    fi
}
declare -A SHED_PKG_LOCAL_OPTIONS=${SHED_PKG_OPTIONS_ASSOC}
# If /usr/include/limits.h is present when building, make enters an infinite loop in glibc 2.26
# HACK: For now, temporarily move the installed /usr/include/limits.h aside when compiling
if [ -e /usr/include/limits.h ]; then
    mv /usr/include/limits.h /usr/include/limits.h.bak
fi

# Patch
patch -Np1 -i "${SHED_PKG_PATCH_DIR}/glibc-2.28-fhs-1.patch" || exit 1

# Configure
mkdir -v build
cd build
if [ -n "${SHED_PKG_LOCAL_OPTIONS[bootstrap]}" ]; then
    # Avoid references to the temporary /tools directory
    ln -sfv /tools/lib/gcc /usr/lib
    # Deal with hard-coded path to m4
    ln -sfv /tools/bin/m4 /usr/bin
fi
if [ -n "${SHED_PKG_LOCAL_OPTIONS[toolchain]}" ]; then
    if [ "$SHED_BUILD_HOST" != "$SHED_NATIVE_TARGET" ]; then
        ../configure --prefix=/tools                    \
                     --host=$SHED_BUILD_HOST            \
                     --build=$(../scripts/config.guess) \
                     --enable-kernel=3.2                \
                     --with-headers=/tools/include      \
                     libc_cv_forced_unwind=yes          \
                     libc_cv_c_cleanup=yes || { shed_glibc_cleanup; exit 1; }
    else
        echo "Unsupported host setting for toolchain build: '$SHED_BUILD_HOST'"
        exit 1
    fi
else
    # HACK: Explicit reference to versioned gcc directory creates a hard dependency
    GCC_INCDIR="/usr/lib/gcc/${SHED_BUILD_TARGET}/8.2.0/include"
    CC="gcc -isystem $GCC_INCDIR -isystem /usr/include" \
    ../configure --prefix=/usr                          \
                 --disable-werror                       \
                 --enable-kernel=3.2                    \
                 --enable-stack-protector=strong        \
                 libc_cv_slibdir=/lib || { shed_glibc_cleanup; exit 1; }
    unset GCC_INCDIR
fi

# Build
make -j $SHED_NUM_JOBS || { shed_glibc_cleanup; exit 1; }
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make DESTDIR="$SHED_FAKE_ROOT" install || { shed_glibc_cleanup; exit 1; }
shed_glibc_cleanup

if [ -n "${SHED_PKG_LOCAL_OPTIONS[toolchain]}" ]; then
    # Compatibility symlink for non ld-linux-armhf awareness
    ln -sv ld-${SHED_PKG_VERSION}.so "${SHED_FAKE_ROOT}/tools/lib/ld-linux.so.3" || exit 1
else
    # Install ncsd config files
    install -v -Dm644 ../nscd/nscd.conf "${SHED_FAKE_ROOT}/etc/nscd.conf" &&
    install -v -Dm644 ../nscd/nscd.tmpfiles "${SHED_FAKE_ROOT}/usr/lib/tmpfiles.d/nscd.conf" &&
    install -v -Dm644 ../nscd/nscd.service "${SHED_FAKE_ROOT}/lib/systemd/system/nscd.service" &&
    mkdir -pv "${SHED_FAKE_ROOT}/var/cache/nscd" &&
    mkdir -pv "${SHED_FAKE_ROOT}/usr/lib/locale" &&

    # Install other default config files
    install -v -dm755 "${SHED_FAKE_ROOT}${SHED_PKG_DEFAULTS_INSTALL_DIR}/etc" &&
    install -v -m644 "${SHED_PKG_CONTRIB_DIR}/locale.conf" "${SHED_FAKE_ROOT}${SHED_PKG_DEFAULTS_INSTALL_DIR}/etc" &&
    install -v -m644 "${SHED_PKG_CONTRIB_DIR}/nsswitch.conf" "${SHED_FAKE_ROOT}${SHED_PKG_DEFAULTS_INSTALL_DIR}/etc" &&
    install -v -m644 "${SHED_PKG_CONTRIB_DIR}/ld.so.conf" "${SHED_FAKE_ROOT}${SHED_PKG_DEFAULTS_INSTALL_DIR}/etc" &&

    # Compatibility symlink for non ld-linux-armhf awareness
    ln -sv ld-${SHED_PKG_VERSION}.so "${SHED_FAKE_ROOT}/lib/ld-linux.so.3" || exit 1

    # 64-bit compatibility symlink
    if [[ $SHED_BUILD_TARGET =~ ^aarch64-.* ]]; then
        mkdir -v "${SHED_FAKE_ROOT}/lib64" &&
        ln -sfv ../lib/ld-linux-aarch64.so.1 "${SHED_FAKE_ROOT}/lib64" || exit 1
    fi
fi
