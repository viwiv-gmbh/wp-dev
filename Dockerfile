ARG WP_VERSION=6.6.2
ARG PHP_VERSION=8.2
FROM wordpress:${WP_VERSION}-php${PHP_VERSION}-apache

ARG NODE_VERSION
ARG APP_USER=dev
ARG VERSION=1.0.0
ARG APP_UID=1000
ARG APP_GID=1000
ARG YQ_VERSION=v4.44.3
ARG MHSENDMAIL_VERSION=v0.2.0-M1
ARG CLAUDE_CODE_VERSION=latest

ENV NODE_VERSION=${NODE_VERSION}
ENV APP_USER=${APP_USER}
ENV VERSION=${VERSION}
ENV WORDPRESS_LOCALE=de_CH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

RUN set -eux; \
    curl -fsSLo /tmp/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar; \
    curl -fsSLo /tmp/wp-cli.phar.sha512 https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar.sha512; \
    echo "$(cat /tmp/wp-cli.phar.sha512)  /tmp/wp-cli.phar" | sha512sum -c -; \
    install -m 0755 /tmp/wp-cli.phar /usr/local/bin/wp; \
    rm -f /tmp/wp-cli.phar /tmp/wp-cli.phar.sha512

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl iproute2 rsync wget zip unzip git libntirpc-dev vim python3-launchpadlib \
    libmagickwand-dev libzip-dev mariadb-client openssh-client && \
    cd /usr/bin && ln -sf python3 /usr/bin/python && \
    rm -rf /var/lib/apt/lists/* 

RUN mkdir -p /usr/local/nvm
ENV NVM_DIR=/usr/local/nvm
ENV PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH
RUN curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 --connect-timeout 20 --max-time 900 -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash && \
    /bin/bash -c "source $NVM_DIR/nvm.sh && nvm install ${NODE_VERSION:-node} && nvm alias default ${NODE_VERSION:-node} && nvm use --delete-prefix ${NODE_VERSION:-node}" && \
    npm install --global yarn @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

RUN mkdir -p /home/$APP_USER && \
    cp -r /root/.bashrc /home/$APP_USER/.bashrc && \
    echo 'export NVM_DIR=/usr/local/nvm' >> /home/$APP_USER/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/$APP_USER/.bashrc

RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') && \
    wget -qO - https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}.tar.gz | \
    tar xz && install -m 0755 yq_linux_${ARCH} /usr/bin/yq && rm -f yq_linux_${ARCH}

RUN (groupadd --gid $APP_GID "$APP_USER" || groupadd "$APP_USER" || true) && \
    (useradd  -l -m -s "/bin/bash" --gid www-data --comment '' --uid $APP_UID "$APP_USER" || \
     useradd  -l -m -s "/bin/bash" --gid www-data --comment '' "$APP_USER" || \
     useradd  -l -m -s "/bin/bash" --gid $APP_GID --comment '' "$APP_USER") && \
    adduser $APP_USER www-data && \
    chown -R $APP_USER:www-data /var/www && \
    chmod -R 775 /var/www && \
    chmod -R g+s /var/www && \
    chown -R $APP_USER:$APP_USER /home/$APP_USER
RUN set -eux; \
    EXPECTED_SIGNATURE="$(curl -fsSL https://composer.github.io/installer.sig)"; \
    curl -fsSL -o /tmp/composer-setup.php https://getcomposer.org/installer; \
    ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"; \
    [ "$EXPECTED_SIGNATURE" = "$ACTUAL_SIGNATURE" ]; \
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer; \
    rm -f /tmp/composer-setup.php && \
    printf '%s\n' 'file_uploads = On' 'memory_limit = 256M' 'upload_max_filesize = 256M' 'post_max_size = 256M' 'max_execution_time = 60' 'max_input_time = 60' > $PHP_INI_DIR/conf.d/wp.ini && \
    ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') && \
    curl --location --silent --show-error --fail --output /usr/local/bin/mhsendmail https://github.com/evertiro/mhsendmail/releases/download/${MHSENDMAIL_VERSION}/mhsendmail_linux_${ARCH} && \
    chmod +x /usr/local/bin/mhsendmail && \
    echo 'sendmail_path="/usr/local/bin/mhsendmail --smtp-addr=mailhog:1025"' > $PHP_INI_DIR/conf.d/mailhog.ini

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY claude-bootstrap.sh /usr/local/bin/claude-bootstrap
RUN chmod +x /usr/local/bin/claude-bootstrap

CMD [ "/entrypoint.sh" ]
