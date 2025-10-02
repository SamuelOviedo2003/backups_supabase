#!/bin/bash
set -euo pipefail

: "${DB_HOST?Need DB_HOST}"
: "${DB_USER?Need DB_USER}"
: "${DB_PASS?Need DB_PASS}"
: "${DB_NAME?Need DB_NAME}"

BACKUP_DIR=${BACKUP_DIR:-/backups}
RCLONE_REMOTE=${RCLONE_REMOTE:-gdrive}
TARGET=${1:-latest}

# Obtener archivo
if [ "$TARGET" = "latest" ]; then
  if ls ${BACKUP_DIR}/*.sql.gz >/dev/null 2>&1; then
    FILE=$(ls -t ${BACKUP_DIR}/*.sql.gz | head -n1)
  else
    echo "No local backups, trying to fetch from remote..."
    rclone copy "${RCLONE_REMOTE}:SupabaseBackups" "$BACKUP_DIR" --include "*.sql.gz" --max-age 3650
    FILE=$(ls -t ${BACKUP_DIR}/*.sql.gz | head -n1)
  fi
else
  FILE="${BACKUP_DIR}/${TARGET}"
fi

if [ ! -f "$FILE" ]; then
  echo "Backup file not found: $FILE"
  exit 1
fi

echo "Restoring from $FILE to ${DB_HOST}:${DB_NAME}"

export PGPASSWORD="$DB_PASS"
export PGSSLMODE="${PGSSLMODE:-require}"

gunzip -c "$FILE" | psql --host="$DB_HOST" --port="${DB_PORT:-5432}" --username="$DB_USER" --dbname="$DB_NAME" --set ON_ERROR_STOP=on

echo "Restore complete"
