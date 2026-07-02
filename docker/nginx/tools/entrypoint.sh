#!/usr/bin/env bash
set -euo pipefail

echo "[nginx] entrypoint starting..."

: "${DOMAIN_NAME:?DOMAIN_NAME is required}"

SSL_DIR="/etc/nginx/ssl"
CRT="${SSL_DIR}/${DOMAIN_NAME}.crt"
KEY="${SSL_DIR}/${DOMAIN_NAME}.key"

mkdir -p "${SSL_DIR}"

# Generate a self-signed cert if missing (common for Inception)
if [ ! -f "${CRT}" ] || [ ! -f "${KEY}" ]; then
  echo "[nginx] generating self-signed TLS cert for ${DOMAIN_NAME}..."
  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -keyout "${KEY}" \
    -out "${CRT}" \
    -subj "/C=FR/ST=IDF/L=Paris/O=42/OU=Inception/CN=${DOMAIN_NAME}"
fi

# Render nginx.conf with env vars (DOMAIN_NAME)
envsubst '${DOMAIN_NAME}' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf

echo "[nginx] starting nginx..."
exec nginx -g "daemon off;"
