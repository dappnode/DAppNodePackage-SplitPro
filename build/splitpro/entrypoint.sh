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

# Construct and EXPORT DATABASE_URL (upstream start.sh sets it but doesn't export it)
if [ -z "$DATABASE_URL" ]; then
    DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_CONTAINER_NAME}:${POSTGRES_PORT}/${POSTGRES_DB}"
    export DATABASE_URL
    echo "Exporting DATABASE_URL" >&2
fi

exec sh start.sh
