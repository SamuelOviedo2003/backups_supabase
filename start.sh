#!/bin/bash
set -euo pipefail

# Asegura dirs
mkdir -p /backups /var/log
touch /var/log/backup.log

# (Opcional) instalar crontab si está en /etc/cron.d
if [ -f /etc/cron.d/supabase-backup ]; then
  crontab /etc/cron.d/supabase-backup || true
fi

# Arranca cron como demonio (no en foreground) para que podamos tailear logs
cron

# Muestra env básicos para debugging (opcional)
echo "ENV:"
env | grep -E 'DB_|UPLOAD_TO_DRIVE|RETENTION_DAYS|PGSSLMODE|RCLONE_REMOTE' || true

# Mantener contenedor vivo mostrando logs del job
tail -F /var/log/backup.log
