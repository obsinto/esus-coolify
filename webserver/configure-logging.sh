#!/bin/sh
set -e

echo "=== Configurando logging do e-SUS PEC ==="

# Aguardar a instalação do eSUS estar completa
if [ ! -f "/opt/e-SUS/webserver/standalone.sh" ]; then
  echo "AVISO: eSUS ainda não está instalado. Pulando configuração de logs."
  exit 0
fi

# Localizar o arquivo log4j.properties do eSUS
LOG4J_CONFIG="/opt/e-SUS/webserver/configuration/log4j.properties"

# Se não existir, procurar em outros locais comuns
if [ ! -f "$LOG4J_CONFIG" ]; then
  echo "Procurando log4j.properties..."
  FOUND_CONFIG=$(find /opt/e-SUS -name "log4j.properties" 2>/dev/null | head -1)

  if [ -n "$FOUND_CONFIG" ]; then
    LOG4J_CONFIG="$FOUND_CONFIG"
    echo "Encontrado em: $LOG4J_CONFIG"
  else
    echo "AVISO: Arquivo log4j.properties não encontrado."
    echo "Criando novo arquivo em: $LOG4J_CONFIG"
    mkdir -p "$(dirname "$LOG4J_CONFIG")"
  fi
fi

# Backup do arquivo original
if [ -f "$LOG4J_CONFIG" ]; then
  echo "Fazendo backup do log4j.properties original..."
  cp "$LOG4J_CONFIG" "${LOG4J_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Copiar a nova configuração
echo "Aplicando nova configuração de logging..."
cat > "$LOG4J_CONFIG" <<'EOF'
# Root logger option
log4j.rootLogger=INFO, stdout, file

# Direct log messages to stdout
log4j.appender.stdout=org.apache.log4j.ConsoleAppender
log4j.appender.stdout.target=System.out
log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
log4j.appender.stdout.layout.conversionPattern=%-5p %d{dd/MM/yy HH:mm:ss} %c{1}: %m%n

# Direct log messages to a log file with daily rotation
log4j.appender.file=org.apache.log4j.DailyRollingFileAppender
log4j.appender.file.file=pec.log
log4j.appender.file.DatePattern='.'yyyy-MM-dd'.'SSS
log4j.appender.file.layout=org.apache.log4j.PatternLayout
log4j.appender.file.layout.conversionPattern=%-5p %d{dd/MM/yy HH:mm:ss} %c{1}: %m%n
EOF

echo "✅ Configuração de logging aplicada com sucesso!"
echo "   Arquivo: $LOG4J_CONFIG"
echo "   Formato de log: pec.log.yyyy-MM-dd.SSS"
echo ""
echo "Nota: O formato final pode variar dependendo da versão do Log4j"
echo "      Logs comprimidos (.gz) podem requerer configuração adicional do Log4j"
