#!/bin/sh
# Script de inicialização do cron para backups automáticos

set -e

echo "=== Configurando backups automáticos ==="

# Criar diretório de backups
mkdir -p /backups

# Criar arquivo de log do cron
touch /var/log/cron.log

# Configurar cron job (todos os dias à meia-noite)
# Formato: minuto hora dia mês dia_da_semana comando
echo "0 0 * * * /usr/local/bin/backup.sh >> /var/log/cron.log 2>&1" > /etc/crontabs/root

# Dar permissões corretas
chmod 0644 /etc/crontabs/root

# Iniciar crond em background
crond -b -l 2 -L /var/log/cron.log

echo "✅ Cron configurado: backup diário à meia-noite (00:00)"
echo "📋 Logs disponíveis em: /var/log/cron.log"
echo "💾 Backups salvos em: /backups"
echo ""
