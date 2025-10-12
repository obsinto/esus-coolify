#!/bin/sh
set -e

echo "=== eSUS Startup Script ==="

# Configurações do banco de dados via variáveis de ambiente (BUILD ARGS)
# Essas variáveis são passadas durante o build do Docker
DB_URL="${APP_DB_URL:-}"
DB_USER="${APP_DB_USER:-}"
DB_PASSWORD="${APP_DB_PASSWORD:-}"

# Se as variáveis não existem, tentar ler do application.properties
CONFIG_FILE="/opt/e-SUS/webserver/config/application.properties"
if [ -z "$DB_URL" ] && [ -f "$CONFIG_FILE" ]; then
  echo "Lendo configurações de $CONFIG_FILE"
  while IFS='=' read -r key value
  do
    key=$(echo "$key" | xargs | tr '.' '_')
    value=$(echo "$value" | xargs)
    if [ ${#key} -le 0 ]; then
      continue
    fi
    export "${key}"="${value}"
  done < "$CONFIG_FILE"

  DB_URL="${spring_datasource_url}"
  DB_USER="${spring_datasource_username}"
  DB_PASSWORD="${spring_datasource_password}"
fi

echo "Database URL = ${DB_URL}"
echo "Username = ${DB_USER}"

# Verificar se o eSUS está instalado
if [ ! -f "/opt/e-SUS/webserver/standalone.sh" ]; then
  echo "=== eSUS não instalado. Iniciando instalação... ==="

  # Verificar se o JAR do instalador existe
  if [ ! -f "/home/downloads/eSUS-AB-PEC.jar" ]; then
    echo "ERRO: Instalador do eSUS não encontrado!"
    exit 1
  fi

  # Aguardar o banco de dados estar pronto
  echo "Aguardando banco de dados estar disponível..."
  for i in $(seq 1 30); do
    if pg_isready -h "$(echo $DB_URL | sed 's/.*\/\/\([^:]*\).*/\1/')" -U "$DB_USER" > /dev/null 2>&1; then
      echo "Banco de dados disponível!"
      break
    fi
    echo "Tentativa $i/30 - Aguardando banco..."
    sleep 2
  done

  # Instalar o eSUS
  cd /home/downloads
  echo "Instalando eSUS com banco de dados: ${DB_URL}"
  echo "s" | java -jar eSUS-AB-PEC.jar -console \
    -url="${DB_URL}" \
    -username="${DB_USER}" \
    -password="${DB_PASSWORD}"

  # Extrair o migrador
  echo "Extraindo migrador..."
  jar xf eSUS-AB-PEC.jar
  cp container/database/migrador.jar /opt/e-SUS/

  echo "=== Instalação concluída! ==="
fi

# Executar migração do banco de dados
if [ -f "/opt/e-SUS/migrador.jar" ]; then
  echo "=== Executando migrações do banco de dados ==="
  java -jar /opt/e-SUS/migrador.jar \
    -url="${DB_URL}" \
    -username="${DB_USER}" \
    -password="${DB_PASSWORD}" || {
    echo "AVISO: Migração falhou ou já está atualizada"
  }
fi

# Iniciar o servidor eSUS
echo "=== Iniciando servidor eSUS ==="
exec sh /opt/e-SUS/webserver/standalone.sh