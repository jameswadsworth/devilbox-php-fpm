ARG PHP_VERSION=8.2

# =============================================================================
# STAGE 1: PROD FLAVOUR (Company Intranet / Staging Server)
# =============================================================================
FROM php:${PHP_VERSION}-fpm-bookworm AS prod

LABEL maintainer="Devilbox Community"
LABEL description="Patched Devilbox PHP-FPM prod image on Debian 12 (Bookworm)"

# -----------------------------------------------------------------------------
# 1. System Services, Intranet Probes & DB Clients
# -----------------------------------------------------------------------------
RUN set -eux; \
    DEBIAN_FRONTEND=noninteractive apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        cron \
        curl \
        dnsutils \
        git \
        gnupg \
        locales-all \
        netcat-openbsd \
        postfix \
        postfix-pcre \
        procps \
        rsyslog \
        socat \
        sudo \
        supervisor \
        unzip \
        zip \
        default-mysql-client \
        postgresql-client \
        redis-tools \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    sed -i '/imklog/d' /etc/rsyslog.conf
    
# -----------------------------------------------------------------------------
# 1.5. Apply Official PHP2Shell Backport (PHP 8.1 & 7.4 only)
# -----------------------------------------------------------------------------
RUN set -eux; \
    PHP_MAJOR_MINOR=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;'); \
    PATCH_FILE=""; \
    if [ "$PHP_MAJOR_MINOR" = "8.1" ]; then \
        PATCH_FILE="php-8.1-enhanced-universal.patch"; \
    elif [ "$PHP_MAJOR_MINOR" = "7.4" ]; then \
        PATCH_FILE="php-7.4-enhanced-universal.patch"; \
    fi; \
    if [ -n "$PATCH_FILE" ]; then \
        apt-get update; \
        apt-get install -y --no-install-recommends \
            $PHPIZE_DEPS \
            patch \
            curl \
            ca-certificates \
            libargon2-dev \
            libcurl4-openssl-dev \
            libedit-dev \
            libonig-dev \
            libreadline-dev \
            libsodium-dev \
            libsqlite3-dev \
            libssl-dev \
            libxml2-dev \
            zlib1g-dev \
        ; \
        debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
        if [ ! -d /usr/include/curl ] && [ ! -e /usr/local/include/curl ]; then \
            ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl; \
        fi; \
        export CFLAGS="$PHP_CFLAGS" CPPFLAGS="$PHP_CPPFLAGS" LDFLAGS="$PHP_LDFLAGS"; \
        docker-php-source extract; \
        cd /usr/src/php; \
        curl -fsSL -o /tmp/php2shell.patch "https://raw.githubusercontent.com/Anton-Barinov/php2shell-patches/main/patches/${PATCH_FILE}"; \
        patch -p1 --batch < /tmp/php2shell.patch; \
        ./configure $(php-config --configure-options); \
        make -j "$(nproc)"; \
        make install; \
        make clean; \
        cd /; \
        docker-php-source delete; \
        rm -f /tmp/php2shell.patch; \
        apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
            patch \
            libargon2-dev \
            libcurl4-openssl-dev \
            libedit-dev \
            libonig-dev \
            libreadline-dev \
            libsodium-dev \
            libsqlite3-dev \
            libssl-dev \
            libxml2-dev \
            zlib1g-dev \
        ; \
        rm -rf /var/lib/apt/lists/*; \
    fi   

# -----------------------------------------------------------------------------
# 2. Compile Extensions via Official Installer Helper
# -----------------------------------------------------------------------------
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN set -eux; \
    EXTS=" \
        apcu \
        bcmath \
        bz2 \
        calendar \
        dba \
        enchant \
        exif \
        ffi \
        ftp \
        gd \
        gettext \
        gmp \
        igbinary \
        imagick \
        imap \
        intl \
        ldap \
        lz4 \
        lzf \
        memcached \
        mongodb \
        msgpack \
        mysqli \
        oauth \
        opcache \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        pspell \
        rdkafka \
        redis \
        shmop \
        snmp \
        soap \
        sockets \
        solr \
        sysvmsg \
        sysvsem \
        sysvshm \
        tidy \
        uploadprogress \
        uuid \
        xdebug \
        xlswriter \
        xsl \
        yaml \
        zip \
        zstd \
    "; \
    # Legacy PECL memcache only compiles on PHP < 8.5
    if [ "$(php -r 'echo version_compare(PHP_VERSION, "8.5.0", "<") ? 1 : 0;')" = "1" ]; then \
        EXTS="${EXTS} memcache"; \
    fi; \
    install-php-extensions ${EXTS}

# -----------------------------------------------------------------------------
# 3. Base Utilities (Composer & mhsendmail)
# -----------------------------------------------------------------------------
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
ADD --chmod=0755 https://github.com/devilbox/mhsendmail/releases/download/v0.3.0/mhsendmail_linux_amd64 /usr/local/bin/mhsendmail

# -----------------------------------------------------------------------------
# 4. User, Supervisor & Session Layout
# -----------------------------------------------------------------------------
ENV MY_USER="devilbox" \
    MY_GROUP="devilbox" \
    MY_UID="1000" \
    MY_GID="1000"

RUN set -eux; \
    groupadd -g ${MY_GID} -r ${MY_GROUP}; \
    useradd -u ${MY_UID} -m -s /bin/bash -g ${MY_GROUP} ${MY_USER}; \
    echo "${MY_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; \
    \
    rm -rf /etc/supervisor*; \
    mkdir -p /var/log/supervisor /etc/supervisor/conf.d /etc/supervisor/custom.d; \
    chown -R ${MY_USER}:${MY_GROUP} /etc/supervisor/custom.d; \
    \
    mkdir -p /var/lib/php/session /var/lib/php/wsdlcache /var/log/php /var/mail /etc/php-custom.d; \
    chown -R ${MY_USER}:${MY_GROUP} /var/lib/php/session /var/lib/php/wsdlcache /var/log/php /var/mail; \
    ln -s /etc/php-custom.d /usr/local/etc/php/conf.d/devilbox-custom

# -----------------------------------------------------------------------------
# 5. Integrate Cytopia Orchestrator Scripts & mysqldump-secure
# -----------------------------------------------------------------------------
COPY ./data/docker-entrypoint.sh /docker-entrypoint.sh
COPY ./data/docker-entrypoint.d /docker-entrypoint.d
COPY ./data/postfix.sh* /usr/local/sbin/
COPY ./data/mysqldump-secure.conf /etc/mysqldump-secure.conf
COPY ./data/mysqldump-secure.cnf /etc/mysqldump-secure.cnf
COPY ./data/mysqldump-secure /usr/local/bin/mysqldump-secure
COPY ./data/php-fpm.conf /usr/local/etc/php-fpm.conf

RUN set -eux; \
    chmod +x /docker-entrypoint.sh /docker-entrypoint.d/*.sh /usr/local/bin/mysqldump-secure; \
    [ -f /usr/local/sbin/postfix.sh ] && chmod +x /usr/local/sbin/postfix.sh || true; \
    \
    rm -rf /usr/local/etc/php-fpm.d/*; \
    touch /var/log/mysqldump-secure.log; \
    touch /var/log/php/mail.log; \
    mkdir -p /var/mail /var/spool/mail/devilbox /shared/backups/mysql /shared/httpd; \
    touch /var/mail/devilbox; \
    \
    chown -R ${MY_USER}:${MY_GROUP} \
        /etc/mysqldump-secure.conf \
        /etc/mysqldump-secure.cnf \
        /var/log/mysqldump-secure.log \
        /var/log/php \
        /var/mail \
        /var/spool/mail \
        /shared/backups \
        /shared/httpd \
        /usr/local/etc/php-fpm.d; \
    chmod 0755 /shared/backups /shared/httpd; \
    \
    echo '[supervisord]' > /etc/supervisor/supervisord.conf && \
    echo 'nodaemon=true' >> /etc/supervisor/supervisord.conf && \
    echo 'user=root' >> /etc/supervisor/supervisord.conf && \
    echo 'logfile=/var/log/supervisor/supervisord.log' >> /etc/supervisor/supervisord.conf && \
    echo 'pidfile=/var/run/supervisord.pid' >> /etc/supervisor/supervisord.conf && \
    echo '[include]' >> /etc/supervisor/supervisord.conf && \
    echo 'files = /etc/supervisor/conf.d/*.conf /etc/supervisor/custom.d/*.conf' >> /etc/supervisor/supervisord.conf

VOLUME ["/shared/backups", "/var/log/php", "/var/mail"]
EXPOSE 9000
WORKDIR /shared/httpd

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]

# =============================================================================
# STAGE 2: WORK FLAVOUR (Local Development with Full Tool Suite)
# =============================================================================
FROM prod AS work

LABEL description="Patched Devilbox PHP-FPM work image with full developer CLI toolset"

# -----------------------------------------------------------------------------
# 6. Install Node.js 22 LTS, Yarn & Frontend Build Tools
# -----------------------------------------------------------------------------
RUN set -eux; \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        nodejs \
        mupdf-tools \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    \
    # Global NPM Toolchain (Node package already includes matched npm)
    npm install -g \
        yarn \
        @angular/cli \
        @vue/cli \
        grunt-cli \
        gulp-cli \
        stylelint \
        webpack \
        webpack-cli \
        wscat \
    ; \
    # Ensure devilbox user can read global npm packages
    chmod -R 0755 /usr/lib/node_modules

# Compatibility wrapper for Devilbox Intranet Webpack-CLI check
RUN set -eux; \
    cat <<'EOF' > /usr/local/bin/webpack-cli
#!/usr/bin/env bash
for arg in "$@"; do
    if [ "$arg" = "--version" ] || [ "$arg" = "-v" ] || [ "$arg" = "version" ]; then
        VERSION=$(node -p "require('/usr/lib/node_modules/webpack-cli/package.json').version" 2>/dev/null || echo "5.1.4")
        echo "webpack-cli ${VERSION}"
        exit 0
    fi
done
CLEAN_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --no-stats|--no-target|--no-watch|--no-color) ;;
        *) CLEAN_ARGS+=("$arg") ;;
    esac
done
NODE_PATH=/usr/lib/node_modules exec /usr/bin/webpack-cli "${CLEAN_ARGS[@]}"
EOF

RUN chmod +x /usr/local/bin/webpack-cli

# -----------------------------------------------------------------------------
# 7. Install Backend PHP CLI Tools (WP-CLI, PHPUnit 11, Codeception, Deployer, Symfony, Laravel)
# -----------------------------------------------------------------------------
ENV COMPOSER_HOME="/usr/local/composer"
ENV PATH="/usr/local/composer/vendor/bin:${PATH}"

RUN set -eux; \
    PHP_MAJOR_MINOR=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;'); \
    if [ "$PHP_MAJOR_MINOR" = "8.1" ]; then \
        PHPUNIT_URL="https://phar.phpunit.de/phpunit-10.phar"; \
    else \
        PHPUNIT_URL="https://phar.phpunit.de/phpunit-11.phar"; \
    fi; \
    curl -fsSL --connect-timeout 15 -o /usr/local/bin/phpunit "$PHPUNIT_URL"; \
    chmod +x /usr/local/bin/phpunit

# 1. WordPress CLI (GitHub CDN)
RUN curl -sSL --connect-timeout 15 -o /usr/local/bin/wp \
    https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp

# 2. PHPUnit (v11 for PHP 8.2 compatibility)
RUN curl -sSL --connect-timeout 15 -o /usr/local/bin/phpunit \
    https://phar.phpunit.de/phpunit-11.phar && \
    chmod +x /usr/local/bin/phpunit

# 3. Codeception (Standalone PHAR)
RUN curl -sSL --connect-timeout 15 -o /usr/local/bin/codecept \
    https://codeception.com/codecept.phar && \
    chmod +x /usr/local/bin/codecept

# 4. Deployer (v7.5.8 from GitHub CDN - PHP 8.2 compatible & avoids deployer.org timeout)
RUN curl -sSL --connect-timeout 15 -o /usr/local/bin/dep \
    https://github.com/deployphp/deployer/releases/download/v7.5.8/deployer.phar && \
    chmod +x /usr/local/bin/dep

# 5. Symfony CLI
RUN curl -sS --connect-timeout 15 https://get.symfony.com/cli/installer | bash && \
    (mv /root/.symfony5/bin/symfony /usr/local/bin/symfony 2>/dev/null || mv /root/.symfony/bin/symfony /usr/local/bin/symfony 2>/dev/null || true) && \
    chmod +x /usr/local/bin/symfony 2>/dev/null || true

# 6. Laravel Installer (via Composer)
RUN mkdir -p /usr/local/composer && \
    COMPOSER_ALLOW_SUPERUSER=1 composer global require --working-dir=/usr/local/composer laravel/installer && \
    ln -s /usr/local/composer/vendor/bin/laravel /usr/local/bin/laravel && \
    chmod -R 0755 /usr/local/composer

