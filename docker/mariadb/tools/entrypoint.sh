#!/usr/bin/env bash
set -euo pipefail

echo "[mariadb] Starting entrypoint..."

# Ensure runtime dir exists for mysql unix socket
mkdir -p /run/mysqld /var/lib/mysql
chown -R mysql:mysql /run/mysqld /var/lib/mysql
chmod 750 /var/lib/mysql
cd /var/lib/mysql

# Read secrets
ROOT_PWD="$(cat /run/secrets/db_root_password)"
DB_PWD="$(cat /run/secrets/db_password)"

ensure_db_and_user() {
  # Temporary isolated start (socket only) to apply grants idempotently
  mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking --socket=/tmp/mysql.sock &
  pid="$!"

  # Wait until server is ready
  for i in {1..60}; do
    mariadb-admin --socket=/tmp/mysql.sock ping >/dev/null 2>&1 && break
    sleep 1
  done

  mariadb-admin --socket=/tmp/mysql.sock ping >/dev/null 2>&1 || {
    echo "[mariadb] ERROR: mariadb not ready after 60s" >&2
    exit 1
  }

  # Ensure root pwd + DB/user/grants (idempotent)
  MYSQL_PWD="${ROOT_PWD}" mariadb --socket=/tmp/mysql.sock <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PWD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PWD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL

  # Stop temp server cleanly
  mariadb-admin --socket=/tmp/mysql.sock -u root -p"${ROOT_PWD}" shutdown
  wait "$pid"
}

# First boot: init database if empty (or empty directory)
if [ ! -d "/var/lib/mysql/mysql" ] || [ -z "$(ls -A /var/lib/mysql/mysql 2>/dev/null)" ]; then
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null
  ensure_db_and_user
else
  # Even if data dir exists, re-ensure user/db/grants (covers preseeded datadir)
  ensure_db_and_user
fi

# Final start (network enabled, reads /etc/mysql/mariadb.conf.d/*.cnf)
exec mysqld --user=mysql --datadir=/var/lib/mysql
