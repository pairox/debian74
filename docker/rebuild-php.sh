#!/bin/sh
set -eu

# Reuse the official image's configure options and install paths. Replacing
# Debian packages alone cannot update the PHP binary under /usr/local.
test "$PHP_VERSION" = '7.4.33'
configure_options="$(php-config --configure-options)"
echo '5fe57ca6ee96d59b36c6e0ca842843c50884f177bef1e85234cf669b577f5e48  /tmp/php74-security.patch' | sha256sum -c -
docker-php-source extract
cd /usr/src/php
patch --batch --fuzz=0 -p1 < /tmp/php74-security.patch

# Both the PHP CLI and FPM must be rebuilt, before compiling PECL extensions.
export CFLAGS="$PHP_CFLAGS" CPPFLAGS="$PHP_CPPFLAGS" LDFLAGS="$PHP_LDFLAGS"
eval "./configure $configure_options"
make -j"${PHP_BUILD_JOBS:-2}"
make install
nm -D /usr/local/bin/php | grep -q ' zend_mm_safe_error_ex$'
nm -D /usr/local/sbin/php-fpm | grep -q ' zend_mm_safe_error_ex$'

# docker-php-ext-install reuses this patched tree in the following build steps.
make clean
printf '%s\n' '712e60f9edfd03f0960fc4fc3c2c375f42b90aa2' > /usr/local/share/php-security-backport
rm /tmp/php74-security.patch
