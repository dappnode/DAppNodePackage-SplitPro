#!/bin/sh
set -e

# Process _FILE env vars — same logic as upstream start.sh
# Reads secrets from files and exports them as env vars
for file_var in $(env | grep -E '^[^=]+_FILE=' | cut -d'=' -f1); do
    base_var="${file_var%_FILE}"
    eval "file_path=\${$file_var:-}"
    eval "base_value=\${$base_var:-}"
    if [ -n "$base_value" ]; then continue; fi
    if [ -z "$file_path" ] || [ ! -f "$file_path" ] || [ ! -r "$file_path" ]; then continue; fi
    value=$(cat "$file_path" | tr -d '\n\r')
    eval "$base_var=\"$value\""
    export "$base_var"
    echo "Set $base_var from $file_var ($file_path)" >&2
done

# Set NEXTAUTH_URL: use value from setup wizard if provided, otherwise auto-detect
# from DAppNode's DynDNS domain, otherwise fall back to the internal package URL.
if [ -z "$NEXTAUTH_URL" ] && [ -n "$_DAPPNODE_GLOBAL_DOMAIN" ]; then
    export NEXTAUTH_URL="https://splitpro.${_DAPPNODE_GLOBAL_DOMAIN}"
    echo "Auto-set NEXTAUTH_URL to $NEXTAUTH_URL" >&2
elif [ -z "$NEXTAUTH_URL" ]; then
    export NEXTAUTH_URL="http://split-pro.public.dappnode:3000"
    echo "Set NEXTAUTH_URL to internal fallback: $NEXTAUTH_URL" >&2
fi

# Publish the public URL to the DAppNode info tab
node -e "
const http = require('http');
const u = new URL('http://my.dappnode/data-send');
u.searchParams.set('key', 'Publicly reachable UI (share with friends)');
u.searchParams.set('data', process.env.NEXTAUTH_URL || '');
const req = http.request(u, {method:'POST'}, r => r.resume());
req.on('error', e => console.error('data-send failed:', e.message));
req.end();
" 2>&1 || true

# Construct and EXPORT DATABASE_URL (upstream start.sh sets it but doesn't export it)
if [ -z "$DATABASE_URL" ]; then
    DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_CONTAINER_NAME}:${POSTGRES_PORT}/${POSTGRES_DB}"
    export DATABASE_URL
    echo "Exporting DATABASE_URL" >&2
fi

exec sh start.sh
