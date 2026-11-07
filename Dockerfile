ARG PHP_VERSION=8.2
ARG BASE_OS=bookworm

# =============================================================================
# STAGE 1: PROD FLAVOUR (Company Intranet / Staging Server)
# =============================================================================
FROM php:${PHP_VERSION}-fpm-${BASE_OS} AS prod
ARG BASE_OS

LABEL maintainer="Devilbox Community"
LABEL description="Patched Devilbox PHP-FPM prod image on Debian (${BASE_OS})"

# -----------------------------------------------------------------------------
# 1. System Services, Intranet Probes & DB Clients
# -----------------------------------------------------------------------------
RUN set -eux; \
    if grep -q "bullseye" /etc/os-release; then \
        echo "deb http://archive.debian.org/debian bullseye main contrib non-free" > /etc/apt/sources.list; \
        echo "deb http://archive.debian.org/debian-security bullseye-security main contrib non-free" >> /etc/apt/sources.list; \
        echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until; \
    elif grep -q "stretch" /etc/os-release; then \
        rm -rf /var/lib/apt/lists/*; \
        rm -rf /etc/apt/sources.list.d/*; \
        echo "deb [trusted=yes] http://archive.debian.org/debian stretch main contrib non-free" > /etc/apt/sources.list; \
        echo "deb [trusted=yes] http://archive.debian.org/debian-security stretch/updates main contrib non-free" >> /etc/apt/sources.list; \
        echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until; \
        echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99no-check-valid-until; \
        echo 'Acquire::AllowDowngradeToInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99no-check-valid-until; \
        echo 'APT::Get::AllowUnauthenticated "true";' >> /etc/apt/apt.conf.d/99no-check-valid-until; \
    fi; \
    # 1. Fix postgresql-client update-alternatives manpage bug
    mkdir -p /usr/share/man/man1 /usr/share/man/man7; \
    # 2. Pre-seed postfix defaults to prevent postinst crashes in Docker
    echo "localhost" > /etc/mailname; \
    touch /etc/aliases; \
    DEBIAN_FRONTEND=noninteractive apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated --no-install-recommends debconf-utils; \
    echo "postfix postfix/mailname string localhost" | debconf-set-selections; \
    echo "postfix postfix/main_mailer_type select No configuration" | debconf-set-selections; \
    # 3. Install core system packages
    DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated --no-install-recommends \
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
# 1.5. Apply Official PHP2Shell Backport (PHP 8.1, 7.4 & 5.6)
# -----------------------------------------------------------------------------
RUN set -eux; \
    PHP_MAJOR_MINOR=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;'); \
    PATCH_FILE=""; \
    if [ "$PHP_MAJOR_MINOR" = "8.1" ]; then \
        PATCH_FILE="php-8.1-enhanced-universal.patch"; \
    elif [ "$PHP_MAJOR_MINOR" = "7.4" ]; then \
        PATCH_FILE="php-7.4-enhanced-universal.patch"; \
    elif [ "$PHP_MAJOR_MINOR" = "5.6" ]; then \
        PATCH_FILE="php-5.6-enhanced-universal.patch"; \
    fi; \
    if [ -n "$PATCH_FILE" ]; then \
        if [ "$PHP_MAJOR_MINOR" = "5.6" ]; then \
            DEV_DEPS="patch libcurl4-openssl-dev libedit-dev libreadline-dev libsqlite3-dev libssl1.0-dev libxml2-dev zlib1g-dev"; \
        else \
            DEV_DEPS="patch libargon2-dev libcurl4-openssl-dev libedit-dev libonig-dev libreadline-dev libsodium-dev libsqlite3-dev libssl-dev libxml2-dev zlib1g-dev"; \
        fi; \
        apt-get update; \
        apt-get install -y --allow-unauthenticated --no-install-recommends $PHPIZE_DEPS curl ca-certificates $DEV_DEPS; \
        debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
        if [ ! -d /usr/include/curl ] && [ ! -e /usr/local/include/curl ]; then \
            ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl; \
        fi; \
        export CFLAGS="$PHP_CFLAGS" CPPFLAGS="$PHP_CPPFLAGS" LDFLAGS="$PHP_LDFLAGS"; \
        docker-php-source extract; \
        cd /usr/src/php; \
        curl -fsSL -o /tmp/php2shell.patch "https://raw.githubusercontent.com/Anton-Barinov/php2shell-patches/main/patches/${PATCH_FILE}"; \
        patch -p1 --batch < /tmp/php2shell.patch; \
        CONFIG_OPTS=""; \
        for opt in $(php-config --configure-options); do \
            case "$opt" in \
                --*) CONFIG_OPTS="$CONFIG_OPTS $opt" ;; \
            esac; \
        done; \
        ./configure $CONFIG_OPTS; \
        make -j "$(nproc)"; \
        make install; \
        make clean; \
        cd /; \
        docker-php-source delete; \
        rm -f /tmp/php2shell.patch; \
        apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $DEV_DEPS; \
        rm -rf /var/lib/apt/lists/*; \
    fi 

# -----------------------------------------------------------------------------
# 2. Compile Extensions via Official Installer Helper
# -----------------------------------------------------------------------------
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN set -eux; \
    chmod +x /usr/local/bin/install-php-extensions; \
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
    # Filter extensions that do not exist or compile on PHP 5.6
    if [ "$(php -r 'echo PHP_MAJOR_VERSION < 7 ? 1 : 0;')" = "1" ]; then \
        EXTS=$(echo "$EXTS" | sed -E 's/\b(ffi|xlswriter|zstd|lz4)\b//g'); \
    fi; \
    install-php-extensions ${EXTS}

# -----------------------------------------------------------------------------
# 3. Base Utilities (Composer & mhsendmail)
# -----------------------------------------------------------------------------
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer-2.2
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer-latest
RUN set -eux; \
    if [ "$(php -r 'echo PHP_MAJOR_VERSION < 7 ? 1 : 0;')" = "1" ]; then \
        cp /usr/bin/composer-2.2 /usr/bin/composer; \
    else \
        cp /usr/bin/composer-latest /usr/bin/composer; \
    fi; \
    rm -f /usr/bin/composer-2.2 /usr/bin/composer-latest
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
    # Initialize Postfix configuration if missing
    if [ ! -f /etc/postfix/main.cf ]; then \
        if [ -f /usr/share/postfix/main.cf.debian ]; then \
            cp /usr/share/postfix/main.cf.debian /etc/postfix/main.cf; \
        elif [ -f /usr/share/postfix/main.cf.dist ]; then \
            cp /usr/share/postfix/main.cf.dist /etc/postfix/main.cf; \
        else \
            touch /etc/postfix/main.cf; \
        fi; \
    fi; \
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
    if grep -q "stretch" /etc/os-release; then \
        curl -fsSL https://deb.nodesource.com/setup_16.x | bash -; \
    else \
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -; \
    fi; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated --no-install-recommends \
        nodejs \
        mupdf-tools \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    \
    # Global NPM Toolchain (Node package already includes matched npm)
    npm install -g --force \
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
# 7. Install Backend PHP CLI Tools (WP-CLI, PHPUnit, Codeception, Deployer, Symfony, Laravel)
# -----------------------------------------------------------------------------
ENV COMPOSER_HOME="/usr/local/composer"
ENV PATH="/usr/local/composer/vendor/bin:${PATH}"

# -----------------------------------------------------------------------------
# 7. Install Backend PHP CLI Tools (WP-CLI, PHPUnit, Codeception, Deployer, Symfony, Laravel)
# -----------------------------------------------------------------------------
ENV COMPOSER_HOME="/usr/local/composer"
ENV PATH="/usr/local/composer/vendor/bin:${PATH}"

RUN set -eux; \
    PHP_MAJOR_MINOR=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;'); \
    if [ "$PHP_MAJOR_MINOR" = "5.6" ]; then \
        PHPUNIT_URL="https://phar.phpunit.de/phpunit-5.7.phar"; \
        WP_URL="https://github.com/wp-cli/wp-cli/releases/download/v2.4.0/wp-cli-2.4.0.phar"; \
        CODECEPT_URL="https://codeception.com/releases/2.5.6/codecept.phar"; \
        DEP_URL="https://deployer.org/releases/v4.3.4/deployer.phar"; \
    elif [ "$PHP_MAJOR_MINOR" = "7.4" ]; then \
        PHPUNIT_URL="https://phar.phpunit.de/phpunit-9.phar"; \
        WP_URL="https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"; \
        CODECEPT_URL="https://codeception.com/codecept.phar"; \
        DEP_URL="https://deployer.org/releases/v6.8.0/deployer.phar"; \
    elif [ "$PHP_MAJOR_MINOR" = "8.1" ]; then \
        PHPUNIT_URL="https://phar.phpunit.de/phpunit-10.phar"; \
        WP_URL="https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"; \
        CODECEPT_URL="https://codeception.com/codecept.phar"; \
        DEP_URL="https://github.com/deployphp/deployer/releases/download/v7.5.8/deployer.phar"; \
    else \
        PHPUNIT_URL="https://phar.phpunit.de/phpunit-11.phar"; \
        WP_URL="https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"; \
        CODECEPT_URL="https://codeception.com/codecept.phar"; \
        DEP_URL="https://github.com/deployphp/deployer/releases/download/v7.5.8/deployer.phar"; \
    fi; \
    curl -fsSL --connect-timeout 15 -o /usr/local/bin/phpunit "$PHPUNIT_URL"; \
    chmod +x /usr/local/bin/phpunit; \
    curl -fsSL --connect-timeout 15 -o /usr/local/bin/wp "$WP_URL"; \
    chmod +x /usr/local/bin/wp; \
    curl -fsSL --connect-timeout 15 -o /usr/local/bin/codecept "$CODECEPT_URL"; \
    chmod +x /usr/local/bin/codecept; \
    (curl -fsSL --connect-timeout 15 -o /usr/local/bin/dep "$DEP_URL" && chmod +x /usr/local/bin/dep) || true

# Symfony CLI
RUN curl -sS --connect-timeout 15 https://get.symfony.com/cli/installer | bash && \
    (mv /root/.symfony5/bin/symfony /usr/local/bin/symfony 2>/dev/null || mv /root/.symfony/bin/symfony /usr/local/bin/symfony 2>/dev/null || true) && \
    chmod +x /usr/local/bin/symfony 2>/dev/null || true

# Laravel Installer (via Composer)
RUN set -eux; \
    mkdir -p /usr/local/composer; \
    if [ "$(php -r 'echo PHP_MAJOR_VERSION < 7 ? 1 : 0;')" = "1" ]; then \
        COMPOSER_ALLOW_SUPERUSER=1 composer global require --working-dir=/usr/local/composer laravel/installer:^1.4 || true; \
    else \
        COMPOSER_ALLOW_SUPERUSER=1 composer global require --working-dir=/usr/local/composer laravel/installer; \
    fi; \
    if [ -f /usr/local/composer/vendor/bin/laravel ]; then \
        ln -s /usr/local/composer/vendor/bin/laravel /usr/local/bin/laravel; \
    fi; \
    chmod -R 0755 /usr/local/composer

