#!/bin/sh

CONFIG_FILE="/opt/e-SUS/webserver/config/application.properties"

# Carrega configurações do application.properties se existir
if [ -f "$CONFIG_FILE" ]; then
  while IFS='=' read -r key value; do
    key=$(echo "$key" | xargs | tr '.' '_')
    value=$(echo "$value" | xargs)
    [ -z "$key" ] && continue
    export "${key}"="${value}"
  done < "$CONFIG_FILE"
fi

# Permite sobrescrever por variáveis de ambiente
spring_datasource_url="${APP_DB_URL:-${spring_datasource_url:-}}"
spring_datasource_username="${APP_DB_USER:-${spring_datasource_username:-}}"
spring_datasource_password="${APP_DB_PASSWORD:-${spring_datasource_password:-}}"

echo "Database URL = ${spring_datasource_url}"
echo "Username = ${spring_datasource_username}"

# Primeira execução: instala o e-SUS se necessário
if [ ! -x "/opt/e-SUS/webserver/standalone.sh" ]; then
  echo "Instalação inicial do e-SUS..."
  echo "s" | java -jar /opt/bootstrap/eSUS-AB-PEC.jar -console -url="${spring_datasource_url}" -username="${spring_datasource_username}" -password="${spring_datasource_password}"
fi

# Função para limpar locks do Liquibase
clear_liquibase_lock() {
  echo "Verificando locks do Liquibase..."
  # Extrai host, porta e database da URL JDBC
  DB_HOST=$(echo "${spring_datasource_url}" | sed 's/.*\/\/\([^:]*\).*/\1/')
  DB_PORT=$(echo "${spring_datasource_url}" | sed 's/.*:\([0-9]*\)\/.*/\1/')
  DB_NAME=$(echo "${spring_datasource_url}" | sed 's/.*\/\([^?]*\).*/\1/')
  
  # Tenta limpar lock via psql se disponível
  if command -v psql >/dev/null 2>&1; then
    PGPASSWORD="${spring_datasource_password}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${spring_datasource_username}" -d "${DB_NAME}" -c "DELETE FROM databasechangeloglock WHERE locked = true;" 2>/dev/null || true
  fi
}

# Tenta executar migração mas não falha se der erro
if [ -f "/opt/bootstrap/migrador.jar" ]; then
  echo "Tentando executar migração do banco de dados..."
  # Usa timeout para evitar travamento
  timeout 30 java -jar /opt/bootstrap/migrador.jar -url="${spring_datasource_url}" -username="${spring_datasource_username}" -password="${spring_datasource_password}" && {
    echo "Migração concluída com sucesso!"
  } || {
    echo "AVISO: Migração falhou ou expirou após 30 segundos."
    echo "Possível migração duplicada detectada."
    echo "Continuando com a inicialização do servidor..."
  }
fi

exec sh /opt/e-SUS/webserver/standalone.sh