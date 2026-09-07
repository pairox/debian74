FROM php:7.4-fpm-bullseye

ARG DEBIAN_SNAPSHOT=20240801T000000Z
ENV COMPOSER_ALLOW_SUPERUSER=1

# PHP 7.4 is EOL and its Bullseye package versions are no longer kept in sync
# on the live mirrors. A Debian snapshot makes builds reproducible.
RUN sed -i \
      -e "s|deb.debian.org/debian-security|snapshot.debian.org/archive/debian-security/${DEBIAN_SNAPSHOT}|g" \
      -e "s|security.debian.org/debian-security|snapshot.debian.org/archive/debian-security/${DEBIAN_SNAPSHOT}|g" \
      -e "s|deb.debian.org/debian|snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT}|g" \
      /etc/apt/sources.list \
    && apt-get -o Acquire::Check-Valid-Until=false update \
    && apt-get install -y --no-install-recommends \
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
      libpng-dev \
      libpq-dev \
      libsqlite3-dev \
      libxslt-dev \
      libzip-dev \
      postgresql-client \
      supervisor \
      zlib1g-dev \
    && curl --fail --location --retry 5 --retry-delay 2 https://pecl.php.net/get/memcached-3.2.0.tgz --output /tmp/memcached.tgz \
    && pecl install /tmp/memcached.tgz \
    && curl --fail --location --retry 5 --retry-delay 2 https://pecl.php.net/get/imagick-3.7.0.tgz --output /tmp/imagick.tgz \
    && printf 'yes\n' | pecl install /tmp/imagick.tgz \
    && rm -f /tmp/memcached.tgz /tmp/imagick.tgz \
    && docker-php-ext-enable imagick memcached \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www
