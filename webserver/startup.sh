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

# Validar configurações do banco de dados
if [ -z "$DB_URL" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
  echo "ERRO: Variáveis de banco de dados não configuradas!"
  echo "  APP_DB_URL: ${DB_URL}"
  echo "  APP_DB_USER: ${DB_USER}"
  echo "  APP_DB_PASSWORD: [${DB_PASSWORD:+configured}${DB_PASSWORD:-NOT SET}]"
  exit 1
fi

# Extrair host do banco de dados da URL JDBC
DB_HOST=$(echo "$DB_URL" | sed 's/.*:\/\/\([^:\/]*\).*/\1/')
DB_PORT=$(echo "$DB_URL" | sed 's/.*:\([0-9]*\)\/.*/\1/')
DB_NAME=$(echo "$DB_URL" | sed 's/.*\/\([^?]*\).*/\1/')

echo "=== Testando conexão com o banco de dados ==="
echo "Host: ${DB_HOST}"
echo "Port: ${DB_PORT}"
echo "Database: ${DB_NAME}"

# Aguardar e testar conexão com o banco
MAX_ATTEMPTS=30
ATTEMPT=0
CONNECTION_OK=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "Tentativa $ATTEMPT/$MAX_ATTEMPTS - Testando conexão..."

  if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" > /dev/null 2>&1; then
    echo "✅ Conexão com banco de dados OK!"
    CONNECTION_OK=true
    break
  fi

  if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
    echo "⏳ Banco ainda não disponível, aguardando 2 segundos..."
    sleep 2
  fi
done

if [ "$CONNECTION_OK" = false ]; then
  echo ""
  echo "❌ ERRO: Não foi possível conectar ao banco de dados após $MAX_ATTEMPTS tentativas!"
  echo ""
  echo "Verifique:"
  echo "  1. O serviço do banco de dados está rodando?"
  echo "  2. As credenciais estão corretas?"
  echo "  3. O host/porta estão corretos?"
  echo ""
  echo "Configuração atual:"
  echo "  URL: ${DB_URL}"
  echo "  User: ${DB_USER}"
  echo "  Host: ${DB_HOST}:${DB_PORT}"
  echo "  Database: ${DB_NAME}"
  exit 1
fi

# Verificar se o eSUS está instalado
if [ ! -f "/opt/e-SUS/webserver/standalone.sh" ]; then
  echo "=== eSUS não instalado. Iniciando instalação... ==="

  # Verificar se o JAR do instalador existe
  if [ ! -f "/home/downloads/eSUS-AB-PEC.jar" ]; then
    echo "ERRO: Instalador do eSUS não encontrado!"
    exit 1
  fi

  # Instalar o eSUS (banco já foi testado acima)
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