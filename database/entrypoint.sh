#!/bin/bash
# Entrypoint customizado para iniciar o cron junto com o PostgreSQL

set -e

echo "=== Inicializando backup automático ==="

# Criar diretório de backups
mkdir -p /backups

# Criar arquivo de log do cron
touch /var/log/cron.log

# Configurar cron job (todos os dias à meia-noite)
echo "0 0 * * * /usr/local/bin/backup.sh >> /var/log/cron.log 2>&1" > /etc/crontabs/root

# Dar permissões corretas
chmod 0644 /etc/crontabs/root

# Iniciar crond em background
crond -b -l 2 -L /var/log/cron.log

echo "✅ Cron configurado: backup diário à meia-noite (00:00)"
echo "📋 Logs disponíveis em: /var/log/cron.log"
echo "💾 Backups salvos em: /backups"
echo ""

# Executar o entrypoint original do PostgreSQL
exec docker-entrypoint.sh "$@"
