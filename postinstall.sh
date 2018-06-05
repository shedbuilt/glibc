#!/bin/bash
declare -A SHED_PKG_LOCAL_OPTIONS=${SHED_PKG_OPTIONS_ASSOC}
if [ -n "${SHED_PKG_LOCAL_OPTIONS[toolchain]}" ]; then
    echo "Error: post-install should not be performed for glibc in toolchain build mode."
    exit 1
elif [ -n "${SHED_PKG_LOCAL_OPTIONS[bootstrap]}" ]; then
    # Adjust toolchain following glibc installation in bootstrap
    mv -v /tools/bin/{ld,ld-old} &&
    mv -v /tools/${SHED_BUILD_TARGET}/bin/{ld,ld-old} &&
    mv -v /tools/bin/{ld-new,ld} &&
    ln -sv /tools/bin/ld /tools/${SHED_BUILD_TARGET}/bin/ld &&
    gcc -dumpspecs | sed -e 's@/tools@@g'                   \
        -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
        -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
            `dirname $(gcc --print-libgcc-file-name)`/specs || exit 1
fi
localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8 &&
localedef -i de_DE -f ISO-8859-1 de_DE &&
localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro &&
localedef -i de_DE -f UTF-8 de_DE.UTF-8 &&
localedef -i en_GB -f UTF-8 en_GB.UTF-8 &&
localedef -i en_HK -f ISO-8859-1 en_HK &&
localedef -i en_PH -f ISO-8859-1 en_PH &&
localedef -i en_US -f ISO-8859-1 en_US &&
localedef -i en_US -f UTF-8 en_US.UTF-8 &&
localedef -i es_MX -f ISO-8859-1 es_MX &&
localedef -i fa_IR -f UTF-8 fa_IR &&
localedef -i fr_FR -f ISO-8859-1 fr_FR &&
localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro &&
localedef -i fr_FR -f UTF-8 fr_FR.UTF-8 &&
localedef -i it_IT -f ISO-8859-1 it_IT &&
localedef -i it_IT -f UTF-8 it_IT.UTF-8 &&
localedef -i ja_JP -f EUC-JP ja_JP &&
localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R &&
localedef -i ru_RU -f UTF-8 ru_RU.UTF-8 &&
localedef -i tr_TR -f UTF-8 tr_TR.UTF-8 &&
localedef -i zh_CN -f GB18030 zh_CN.GB18030 || exit 1
