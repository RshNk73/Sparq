#!/bin/sh
export PATH=/usr/bin:$PATH
rm -f config.cache acconfig.h

glibtoolize --force

touch stamp-h

aclocal
autoconf
autoheader
automake --add-missing

# aclocal
# autoheader

# autoconf
# automake -a

./configure #--with-mathpp=/usr

