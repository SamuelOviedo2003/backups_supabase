FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Instala dependencias
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    cron \
    ca-certificates \
    curl \
    gzip \
    findutils \
    unzip \
    && curl https://rclone.org/install.sh | bash \
    && rm -rf /var/lib/apt/lists/*

# Copia scripts
COPY backup.sh /usr/local/bin/backup.sh
COPY restore.sh /usr/local/bin/restore.sh
COPY start.sh /usr/local/bin/start.sh

# Copia crontab
COPY crontab /etc/cron.d/backup-cron

# Permisos
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/restore.sh /usr/local/bin/start.sh \
    && chmod 0644 /etc/cron.d/backup-cron \
    && crontab /etc/cron.d/backup-cron

# Directorios
RUN mkdir -p /backups /var/log && touch /var/log/backup.log

VOLUME ["/backups", "/root/.config/rclone"]

CMD ["/usr/local/bin/start.sh"]

