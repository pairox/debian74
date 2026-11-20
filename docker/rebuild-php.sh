#!/bin/sh
set -eu

# Reuse the official image's configure options and install paths. Replacing
# Debian packages alone cannot update the PHP binary under /usr/local.
test "$PHP_VERSION" = '7.4.33'
configure_options="$(sh /tmp/php-config-upstream --configure-options)"
echo '924846abf93bc613815c55dd3f5809377813ac62a9ec4eb3778675b82a27b927  /usr/src/php.tar.xz' | sha256sum -c -
cd /tmp/php74-patches
sha256sum -c SHA256SUMS
docker-php-source extract
cd /usr/src/php
while IFS= read -r patch_name; do
    patch --batch --fuzz=0 -p1 < "/tmp/php74-patches/$patch_name"
done < /tmp/php74-patches/series

# Both the PHP CLI and FPM must be rebuilt, before compiling PECL extensions.
export CFLAGS="$PHP_CFLAGS" CPPFLAGS="$PHP_CPPFLAGS" LDFLAGS="$PHP_LDFLAGS"
# Regenerate configure for the compatibility fixes; use maintained system PCRE2.
./buildconf --force
eval "./configure $configure_options --with-external-pcre"
make -j"${PHP_BUILD_JOBS:-2}"
make install
nm -D /usr/local/bin/php | grep -q ' zend_mm_safe_error_ex$'
nm -D /usr/local/sbin/php-fpm | grep -q ' zend_mm_safe_error_ex$'

# docker-php-ext-install reuses this patched tree in the following build steps.
make clean
mkdir -p /usr/local/share/php-security
cp /tmp/php74-patches/series /tmp/php74-patches/SHA256SUMS /tmp/php74-patches/README.md /usr/local/share/php-security/
printf '%s\n' 'sury-7.4.33-37-20261119' > /usr/local/share/php-security-backport
rm -rf /tmp/php74-patches
rm /tmp/php-config-upstream
