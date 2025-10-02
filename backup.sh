#!/bin/bash
set -euo pipefail

# Requeridos
: "${DB_HOST?Need to set DB_HOST}"
: "${DB_USER?Need to set DB_USER}"
: "${DB_PASS?Need to set DB_PASS}"
: "${DB_NAME?Need to set DB_NAME}"

BACKUP_DIR=${BACKUP_DIR:-/backups}
RCLONE_REMOTE=${RCLONE_REMOTE:-gdrive}
UPLOAD_TO_DRIVE=${UPLOAD_TO_DRIVE:-false}

mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +"%F_%H-%M-%S")
FILE="${BACKUP_DIR}/supabase_backup_${TIMESTAMP}.sql.gz"

echo "[$(date)] Starting pg_dump -> $FILE"

export PGPASSWORD="$DB_PASS"
export PGSSLMODE="${PGSSLMODE:-require}"

pg_dump \
  --host="$DB_HOST" \
  --port="${DB_PORT:-5432}" \
  --username="$DB_USER" \
  --dbname="$DB_NAME" \
  --no-owner \
  --no-privileges \
  --exclude-schema=pg_catalog \
  --exclude-schema=information_schema \
  --exclude-schema=pg_toast \
  --exclude-schema=pg_temp* \
  --exclude-schema=auth \
  --exclude-schema=storage \
  --exclude-schema=graphql_public \
  --exclude-schema=pgbouncer \
  --exclude-schema=extensions \
  --format=plain \
  --inserts \
  | sed '/^CREATE EVENT TRIGGER/d;/^ALTER EVENT TRIGGER/d;/^COMMENT ON EVENT TRIGGER/d' \
  | sed 's/);$/) ON CONFLICT DO NOTHING;/' \
  | gzip > "$FILE"

echo "[$(date)] Dump complete: $FILE"

# ====== Retention policy ======
# 1) Mantener últimos 7 diarios
ls -1t "$BACKUP_DIR"/supabase_backup_*.sql.gz | sed -e '1,7d' | xargs -r rm -f

# 2) Mantener solo 1 por mes (el más nuevo de cada mes)
for month in $(date +%Y)-{01..12}; do
  ls -1t "$BACKUP_DIR"/supabase_backup_${month}*.sql.gz 2>/dev/null | sed -e '1d' | xargs -r rm -f
done

# 3) Mantener solo 1 por año (el más nuevo de cada año)
for year in $(date +%Y); do
  ls -1t "$BACKUP_DIR"/supabase_backup_${year}-*.sql.gz 2>/dev/null | sed -e '1d' | xargs -r rm -f
done

echo "[$(date)] Retention policy applied"

if [ "$UPLOAD_TO_DRIVE" = "true" ]; then
  echo "[$(date)] Uploading to rclone remote ${RCLONE_REMOTE}:SupabaseBackups"
  rclone copy --progress "$FILE" "${RCLONE_REMOTE}:SupabaseBackups"
fi

echo "[$(date)] Backup finished"
