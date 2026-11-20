FROM php:7.4.33-fpm-bullseye AS php-upstream

FROM debian:bookworm-slim

ARG PHP_BUILD_JOBS=2
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    PHP_VERSION=7.4.33 \
    PHP_INI_DIR=/usr/local/etc/php \
    PHPIZE_DEPS="autoconf dpkg-dev file g++ gcc libc-dev make pkg-config re2c" \
    PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64" \
    PHP_LDFLAGS="-Wl,-O1 -Wl,-z,relro,-z,now -pie"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"

LABEL io.pairox.php.security-backport="sury-7.4.33-37-20261119" \
      io.pairox.image.version="7.4.33-20261120"

# Only source, shell helpers and configuration come from the EOL image.
# No Bullseye binaries, libraries or extensions enter the final image.
COPY --from=php-upstream /usr/src/php.tar.xz /usr/src/php.tar.xz
COPY --from=php-upstream /usr/local/bin/docker-php-* /usr/local/bin/
COPY --from=php-upstream /usr/local/bin/php-config /tmp/php-config-upstream
COPY --from=php-upstream /usr/local/etc/ /usr/local/etc/

COPY docker/patches/ /tmp/php74-patches/
COPY docker/rebuild-php.sh /tmp/rebuild-php.sh
COPY docker/verify-php-security.sh /usr/local/bin/verify-php-security

# Live Bookworm security/LTS repositories replace the August 2024 snapshot.
RUN printf 'Package: php*\nPin: release *\nPin-Priority: -1\n' > /etc/apt/preferences.d/no-debian-php \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
      $PHPIZE_DEPS \
      bison \
      patch \
      xz-utils \
      libargon2-dev \
      libcurl4-openssl-dev \
      libreadline-dev \
      libsodium-dev \
      libssl-dev \
      libxml2-dev \
      ca-certificates \
      curl \
      git \
      libfreetype6-dev \
      libgcrypt-dev \
      libicu-dev \
      libjpeg62-turbo-dev \
      libmagickwand-dev \
      libmemcached-dev \
      libonig-dev \
      libpcre2-dev \
      libpng-dev \
      libpq-dev \
      libsqlite3-dev \
      libxslt-dev \
      libzip-dev \
      postgresql-client \
      supervisor \
      zlib1g-dev \
    && sh /tmp/rebuild-php.sh \
    && rm /tmp/rebuild-php.sh \
    && curl --fail --location --retry 5 --retry-delay 2 https://pecl.php.net/get/memcached-3.4.0.tgz --output /tmp/memcached.tgz \
    && echo 'c163434eb0da97c8f45c7ad41d979d381f8b81c49402b1b90b063987fb37972e  /tmp/memcached.tgz' | sha256sum -c - \
    && pecl install /tmp/memcached.tgz \
    && curl --fail --location --retry 5 --retry-delay 2 https://pecl.php.net/get/imagick-3.8.1.tgz --output /tmp/imagick.tgz \
    && echo '3a3587c0a524c17d0dad9673a160b90cd776e836838474e173b549ed864352ee  /tmp/imagick.tgz' | sha256sum -c - \
    && printf 'yes\n' | pecl install /tmp/imagick.tgz \
    && rm -f /tmp/memcached.tgz /tmp/imagick.tgz \
    && docker-php-ext-enable imagick memcached \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$PHP_BUILD_JOBS" \
      calendar \
      gd \
      intl \
      json \
      mbstring \
      opcache \
      pcntl \
      pdo_pgsql \
      pgsql \
      xml \
      xsl \
      zip \
    && docker-php-ext-enable opcache \
    && docker-php-source delete \
    && rm -f /usr/src/php.tar.xz \
    && rm -rf /tmp/pear /root/.pearrc \
    && mkdir -p /usr/local/share/php-security /var/www/html \
    && chown www-data:www-data /var/www/html \
    && dpkg-query -W > /usr/local/share/php-security/debian-packages.txt \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

RUN printf 'session.upload_progress.enabled=0\n' > "$PHP_INI_DIR/conf.d/zz-security.ini" \
    && chmod +x /usr/local/bin/verify-php-security \
    && /usr/local/bin/verify-php-security

WORKDIR /var/www
ENTRYPOINT ["docker-php-entrypoint"]
STOPSIGNAL SIGQUIT
EXPOSE 9000
CMD ["php-fpm"]
