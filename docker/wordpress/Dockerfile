# WordPress + PHP-FPM (Debian 12)
FROM debian:bookworm-slim

# Install PHP-FPM + extensions + tools
RUN apt-get update && apt-get install -y --no-install-recommends \
      php8.2-fpm php8.2-mysql php8.2-curl php8.2-gd php8.2-xml php8.2-mbstring php8.2-zip \
      curl ca-certificates mariadb-client tar \
    && rm -rf /var/lib/apt/lists/*

# Download WordPress core into /usr/src/wordpress (NOT /var/www/html)
# So a volume mounted on /var/www/html won't hide the core.
RUN mkdir -p /usr/src/wordpress /var/www/html \
    && curl -fsSL https://wordpress.org/latest.tar.gz -o /tmp/wp.tar.gz \
    && tar -xzf /tmp/wp.tar.gz -C /usr/src \
    && mv /usr/src/wordpress/* /usr/src/wordpress/. 2>/dev/null || true \
    && rm -rf /tmp/wp.tar.gz

# Install wp-cli
RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
      -o /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp

# PHP-FPM pool config
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

# Entrypoint
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm8.2", "-F"]
