FROM debian:buster

LABEL maintainer="Chinkesh Kumar"

# Let the container know that there is no tty
ENV DEBIAN_FRONTEND noninteractive
ENV NGINX_VERSION 1.19.10-1~buster
ENV php_conf /etc/php/8.1/fpm/php.ini
ENV fpm_conf /etc/php/8.1/fpm/pool.d/www.conf

# Add Oracle Path to ENV
ENV ORACLE_HOME=/opt/oracle/instantclient_19_13
ENV LD_LIBRARY_PATH=${ORACLE_HOME}


# Install Basic Requirements
RUN buildDeps='curl gcc make autoconf libc-dev zlib1g-dev pkg-config' \
    && set -x \
    && apt-get update \
    && apt-get install --no-install-recommends $buildDeps --no-install-suggests -q -y libaio1 gnupg2 dirmngr wget zip unzip apt-transport-https lsb-release ca-certificates \
    && \
    NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
	    found=''; \
	    for server in \
		  ha.pool.sks-keyservers.net \
		  hkp://keyserver.ubuntu.com:80 \
		  hkp://p80.pool.sks-keyservers.net:80 \
		  pgp.mit.edu \
	    ; do \
		  echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
		  apt-key adv --batch --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
	    done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
    echo "deb http://nginx.org/packages/mainline/debian/ buster nginx" >> /etc/apt/sources.list \
    && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list \
	&& wget https://download.oracle.com/otn_software/linux/instantclient/1913000/instantclient-basic-linux.x64-19.13.0.0.0dbru-2.zip -P /tmp/oracle \
	&& wget https://download.oracle.com/otn_software/linux/instantclient/1913000/instantclient-sdk-linux.x64-19.13.0.0.0dbru-2.zip -P /tmp/oracle \
	&& unzip /tmp/oracle/instantclient-basic-linux.x64-19.13.0.0.0dbru-2 -d /tmp/oracle/ \
	&& unzip /tmp/oracle/instantclient-sdk-linux.x64-19.13.0.0.0dbru-2 -d /tmp/oracle/ \
	&& mkdir -p ${ORACLE_HOME} \
	&& mv /tmp/oracle/instantclient_19_13 /opt/oracle/ \
	&& echo ${ORACLE_HOME} > /etc/ld.so.conf.d/oracle-instantclient.conf \ 
	&& ldconfig \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -q -y \
	apt-utils \
	python-pip \
	python-setuptools \
	libmemcached-dev \
	libmemcached11 \
	libmagickwand-dev \
	nginx=${NGINX_VERSION} \
	php8.1-fpm \
	php8.1-cli \
	php8.1-bcmath \
	php8.1-dev \
	php8.1-common \
	php8.1-opcache \
	php8.1-readline \
	php8.1-mbstring \
	php8.1-curl \
	php8.1-gd \
	php8.1-imagick \
	php8.1-mysql \
	php8.1-zip \
	php8.1-pgsql \
	php8.1-intl \
	php8.1-xml \
	php8.1-ldap \
	php8.1-fileinfo \
	php-pear \
    && pecl -d php_suffix=8.1 install -o -f redis memcached \
	&& echo 'instantclient,/opt/oracle/instantclient_19_13' | pecl install -f oci8-3.0.1 \
    && mkdir -p /run/php \
    && pip install wheel \
    && pip install supervisor supervisor-stdout \
    && echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d \
    && rm -rf /etc/nginx/conf.d/default.conf \
    && sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${php_conf} \
    && sed -i -e "s/memory_limit\s*=\s*.*/memory_limit = 256M/g" ${php_conf} \
    && sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" ${php_conf} \
    && sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" ${php_conf} \
    && sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${php_conf} \
    && sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/8.1/fpm/php-fpm.conf \
    && sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" ${fpm_conf} \
    && sed -i -e "s/pm.max_children = 5/pm.max_children = 4/g" ${fpm_conf} \
    && sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" ${fpm_conf} \
    && sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" ${fpm_conf} \
    && sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" ${fpm_conf} \
    && sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" ${fpm_conf} \
    && sed -i -e "s/www-data/nginx/g" ${fpm_conf} \
    && sed -i -e "s/^;clear_env = no$/clear_env = no/" ${fpm_conf} \
	&& echo "extension=oci8.so" > /etc/php/8.1/mods-available/oci8.ini \
    && echo "extension=redis.so" > /etc/php/8.1/mods-available/redis.ini \
    && echo "extension=memcached.so" > /etc/php/8.1/mods-available/memcached.ini \
    && echo "extension=imagick.so" > /etc/php/8.1/mods-available/imagick.ini \
    && ln -sf /etc/php/8.1/mods-available/oci8.ini /etc/php/8.1/fpm/conf.d/20-oci8.ini \
    && ln -sf /etc/php/8.1/mods-available/oci8.ini /etc/php/8.1/cli/conf.d/20-oci8.ini \
    && ln -sf /etc/php/8.1/mods-available/redis.ini /etc/php/8.1/fpm/conf.d/20-redis.ini \
    && ln -sf /etc/php/8.1/mods-available/redis.ini /etc/php/8.1/cli/conf.d/20-redis.ini \
    && ln -sf /etc/php/8.1/mods-available/memcached.ini /etc/php/8.1/fpm/conf.d/20-memcached.ini \
    && ln -sf /etc/php/8.1/mods-available/memcached.ini /etc/php/8.1/cli/conf.d/20-memcached.ini \
    && ln -sf /etc/php/8.1/mods-available/imagick.ini /etc/php/8.1/fpm/conf.d/20-imagick.ini \
    && ln -sf /etc/php/8.1/mods-available/imagick.ini /etc/php/8.1/cli/conf.d/20-imagick.ini \
	# Cleanup
	&& rm -rf /tmp/* \
    && apt-get purge -y --auto-remove $buildDeps \
    && apt-get clean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*

# Supervisor config
COPY ./supervisord.conf /etc/supervisord.conf

# Override nginx's default config
COPY ./default.conf /etc/nginx/conf.d/default.conf

# Override default nginx welcome page
COPY html /usr/share/nginx/html

# Setup Volume
VOLUME ["/usr/share/nginx/html"]

# Copy Scripts
COPY ./start.sh /start.sh

EXPOSE 80

CMD ["/start.sh"]
