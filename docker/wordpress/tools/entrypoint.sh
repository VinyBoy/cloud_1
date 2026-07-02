#!/usr/bin/env bash
set -euo pipefail

echo "[wordpress] entrypoint starting..."

# --- Secrets (Docker secrets -> files) ---
DB_PWD="$(cat /run/secrets/db_password)"
WP_ADMIN_PWD="$(cat /run/secrets/wp_admin_password)"
WP_USER_PWD="$(cat /run/secrets/wp_user_password)"

# --- Paths ---
WP_PATH="/var/www/html"
WP_SRC="/usr/src/wordpress"

# --- Ensure WordPress files exist even if /var/www/html is a fresh volume ---
# If wp-settings.php isn't present, we assume the directory is empty and copy core files.
if [ ! -f "${WP_PATH}/wp-settings.php" ]; then
  echo "[wordpress] WordPress core not found in ${WP_PATH}. Copying from image..."
  cp -a "${WP_SRC}/." "${WP_PATH}/"
  chown -R www-data:www-data "${WP_PATH}"
fi

# --- Wait for MariaDB (robust readiness) ---
echo "[wordpress] waiting for mariadb..."
for i in {1..60}; do
  MYSQL_PWD="${DB_PWD}" mariadb -h mariadb -u "${MYSQL_USER}" -e "SELECT 1" >/dev/null 2>&1 && break
  sleep 1
done

MYSQL_PWD="${DB_PWD}" mariadb -h mariadb -u "${MYSQL_USER}" -e "SELECT 1" >/dev/null 2>&1 || {
  echo "[wordpress] ERROR: mariadb not ready after 60s" >&2
  exit 1
}

# --- First boot: generate wp-config + install + create user ---
if [ ! -f "${WP_PATH}/wp-config.php" ]; then
  echo "[wordpress] first boot detected (no wp-config.php). Configuring..."

  wp config create \
    --allow-root \
    --path="${WP_PATH}" \
    --dbname="${MYSQL_DATABASE}" \
    --dbuser="${MYSQL_USER}" \
    --dbpass="${DB_PWD}" \
    --dbhost="mariadb:3306"

  wp core install \
    --allow-root \
    --path="${WP_PATH}" \
    --url="https://${DOMAIN_NAME}" \
    --title="${WP_TITLE}" \
    --admin_user="${WP_ADMIN_USER}" \
    --admin_password="${WP_ADMIN_PWD}" \
    --admin_email="${WP_ADMIN_EMAIL}"

  wp user create \
    --allow-root \
    --path="${WP_PATH}" \
    "${WP_USER}" "${WP_USER_EMAIL}" \
    --user_pass="${WP_USER_PWD}" \
    --role="author"

  chown -R www-data:www-data "${WP_PATH}"
  echo "[wordpress] installation done."
else
  echo "[wordpress] wp-config.php already exists, skipping install."
fi

echo "[wordpress] starting php-fpm..."
exec "$@"