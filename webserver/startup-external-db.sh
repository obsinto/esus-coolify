#!/bin/sh

CONFIG_FILE="/opt/e-SUS/webserver/config/application.properties"

# Priorizar variáveis de ambiente sobre o arquivo de configuração
if [ -n "$APP_DB_URL" ]; then
  spring_datasource_url="$APP_DB_URL"
  spring_datasource_username="$APP_DB_USER"
  spring_datasource_password="$APP_DB_PASSWORD"
  echo "Usando configuração de banco de dados de variáveis de ambiente"
else
  echo "Usando configuração de banco de dados de application.properties"
  # Ler do arquivo de configuração se as variáveis não existirem
  if [ -f "$CONFIG_FILE" ]; then
    while IFS='=' read -r key value
    do
      key=$(echo "$key" | xargs | tr '.' '_')
      value=$(echo "$value" | xargs)
      if [ ${#key} -le 0 ]; then
        continue
      fi
      export "${key}"="${value}"
    done < "$CONFIG_FILE"
  fi
fi

echo "Database URL = ${spring_datasource_url}"
echo "Username = ${spring_datasource_username}"

# Executar migração do banco de dados
if [ -f "/opt/e-SUS/migrador.jar" ]; then
  echo "Executando migração do banco de dados..."
  java -jar /opt/e-SUS/migrador.jar \
    -url="${spring_datasource_url}" \
    -username="${spring_datasource_username}" \
    -password="${spring_datasource_password}"
else
  echo "AVISO: migrador.jar não encontrado, pulando migração"
fi

# Iniciar o servidor eSUS
echo "Iniciando servidor eSUS..."
sh /opt/e-SUS/webserver/standalone.sh
