FROM php:8.2.0RC4-zts-bullseye AS php-base

ENV PHP_URL="https://github.com/dunglas/php-src/archive/refs/heads/frankenphp-8.2.tar.gz"
ENV PHP_ASC_URL=""
ENV PHP_SHA256=""

FROM golang:bullseye AS builder

ENV PHPIZE_DEPS \
    autoconf \
    dpkg-dev \
    file \
    g++ \
    gcc \
    libc-dev \
    make \
    pkg-config \
    re2c

RUN apt-get update && \
    apt-get -y --no-install-recommends install \
    $PHPIZE_DEPS \
    libargon2-dev \
    libcurl4-openssl-dev \
    libonig-dev \
    libreadline-dev \
    libsodium-dev \
    libsqlite3-dev \
    libssl-dev \
    libxml2-dev \
    zlib1g-dev \
    && \
    apt-get clean

COPY --from=php-base /usr/local/include/php/ /usr/local/include/php
COPY --from=php-base /usr/local/lib/libphp.* /usr/local/lib
COPY --from=php-base /usr/local/lib/php/ /usr/local/lib/php
COPY --from=php-base /usr/local/php/ /usr/local/php
COPY --from=php-base /usr/local/bin/ /usr/local/bin
COPY --from=php-base /usr/src /usr/src

WORKDIR /go/src/app

COPY go.mod go.sum ./
RUN go get -v ./...

RUN mkdir caddy && cd caddy
COPY go.mod go.sum ./

RUN go get -v ./... && \
    cd ..

COPY . .

RUN cd caddy/frankenphp && \
    go build

RUN ls -lah caddy/frankenphp && \
    cp caddy/frankenphp/frankenphp /usr/local/bin/frankenphp

RUN ls -lah /usr/local/bin

RUN ls -lah /etc && \
    cp caddy/frankenphp/Caddyfile /etc/Caddyfile

CMD [ "frankenphp", "run", "--config", "/etc/Caddyfile" ]

FROM php-base AS final

WORKDIR /app

RUN mkdir -p /app/public
RUN echo '<?php phpinfo();' > /app/public/index.php

COPY --from=builder /usr/local/bin/frankenphp /usr/local/bin/frankenphp
COPY --from=builder /etc/Caddyfile /etc/Caddyfile

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions pdo_mysql gd opcache apcu redis zip intl

COPY "custom.ini" "/usr/local/etc/php/conf.d/99_custom.ini"

ENTRYPOINT [ "frankenphp", "run", "--config", "/etc/Caddyfile" ]
