FROM postgres:9.6.13-alpine

ENV POSTGRES_DB esus
ENV POSTGRES_USER postgres
ENV POSTGRES_PASSWORD esus

# Instalar AWS CLI (opcional, para backups em S3)
# Descomente as linhas abaixo se quiser habilitar backups S3
# RUN apk add --no-cache python3 py3-pip && \
#     pip3 install --upgrade pip && \
#     pip3 install awscli && \
#     rm -rf /var/cache/apk/*

# Copiar scripts de backup
COPY backup.sh /usr/local/bin/backup.sh
COPY init-cron.sh /docker-entrypoint-initdb.d/init-cron.sh

# Tornar scripts executáveis
RUN chmod +x /usr/local/bin/backup.sh && \
    chmod +x /docker-entrypoint-initdb.d/init-cron.sh

EXPOSE 5432
