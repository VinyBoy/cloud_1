FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-server mariadb-client ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Ensure directories exist (runtime + config path)
RUN mkdir -p /run/mysqld /etc/mysql/mariadb.conf.d \
    && chown -R mysql:mysql /run/mysqld

# Replace/complete MariaDB server config (bind-address etc.)
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# Entrypoint script
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
