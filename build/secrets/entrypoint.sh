#!/bin/sh
set -e

CONFIG_DIR="/config"

mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/POSTGRES_PASSWORD" ]; then
  openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c32 > "$CONFIG_DIR/POSTGRES_PASSWORD"
fi

if [ ! -f "$CONFIG_DIR/NEXTAUTH_SECRET" ]; then
  openssl rand -base64 32 > "$CONFIG_DIR/NEXTAUTH_SECRET"
fi

sleep infinity
