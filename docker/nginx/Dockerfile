FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      nginx openssl ca-certificates gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Create runtime dirs (some setups need them explicitly)
RUN mkdir -p /run/nginx /var/www/html /etc/nginx/ssl /etc/nginx/templates

# Template conf (rendered by envsubst at container start)
COPY conf/nginx.conf /etc/nginx/templates/nginx.conf.template

# Entrypoint
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
