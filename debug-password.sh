#!/bin/bash

echo "================================"
echo "eSUS - Debug de Senha do Banco"
echo "================================"
echo ""

# Encontrar containers
DATABASE_CONTAINER=$(docker ps --filter "name=database" --format "{{.Names}}" | head -1)
WEBSERVER_CONTAINER=$(docker ps --filter "name=webserver" --format "{{.Names}}" | head -1)

if [ -z "$DATABASE_CONTAINER" ]; then
  echo "❌ Container do database não encontrado!"
  exit 1
fi

if [ -z "$WEBSERVER_CONTAINER" ]; then
  echo "❌ Container do webserver não encontrado!"
  exit 1
fi

echo "✅ Containers encontrados:"
echo "   Database: $DATABASE_CONTAINER"
echo "   Webserver: $WEBSERVER_CONTAINER"
echo ""

# 1. Verificar variáveis de ambiente do webserver
echo "================================"
echo "1. Variáveis de ambiente do WEBSERVER"
echo "================================"
docker exec $WEBSERVER_CONTAINER sh -c 'echo "APP_DB_URL: $APP_DB_URL"; echo "APP_DB_USER: $APP_DB_USER"; echo "APP_DB_PASSWORD: [${APP_DB_PASSWORD:+SET (${#APP_DB_PASSWORD} chars)}${APP_DB_PASSWORD:-NOT SET}]"'
echo ""

# 2. Verificar variáveis de ambiente do database
echo "================================"
echo "2. Variáveis de ambiente do DATABASE"
echo "================================"
docker exec $DATABASE_CONTAINER sh -c 'echo "POSTGRES_DB: $POSTGRES_DB"; echo "POSTGRES_USER: $POSTGRES_USER"; echo "POSTGRES_PASSWORD: [${POSTGRES_PASSWORD:+SET (${#POSTGRES_PASSWORD} chars)}${POSTGRES_PASSWORD:-NOT SET}]"'
echo ""

# 3. Testar conexão com a senha do webserver
echo "================================"
echo "3. Testando conexão do WEBSERVER → DATABASE"
echo "================================"
WEBSERVER_PASSWORD=$(docker exec $WEBSERVER_CONTAINER sh -c 'echo $APP_DB_PASSWORD')
if docker exec $DATABASE_CONTAINER sh -c "PGPASSWORD='$WEBSERVER_PASSWORD' psql -U postgres -d esus -c 'SELECT 1' > /dev/null 2>&1"; then
  echo "✅ Webserver CONSEGUE conectar com sua senha"
else
  echo "❌ Webserver NÃO consegue conectar com sua senha!"
fi
echo ""

# 4. Ver últimas 20 linhas do log do PostgreSQL
echo "================================"
echo "4. Últimas tentativas de conexão (log PostgreSQL)"
echo "================================"
docker logs $DATABASE_CONTAINER --tail 30 2>&1 | grep -E "(FATAL|ERROR|authentication|password)" || echo "Nenhum erro recente"
echo ""

# 5. Ver conexões ativas
echo "================================"
echo "5. Conexões ATIVAS no banco de dados"
echo "================================"
docker exec $DATABASE_CONTAINER psql -U postgres -d esus -c "SELECT pid, usename, application_name, client_addr, state, query FROM pg_stat_activity WHERE datname = 'esus';" 2>/dev/null || echo "Não foi possível consultar conexões ativas"
echo ""

# 6. Verificar configuração de autenticação
echo "================================"
echo "6. Configuração de autenticação (pg_hba.conf)"
echo "================================"
docker exec $DATABASE_CONTAINER cat /var/lib/postgresql/data/pg_hba.conf | grep -v "^#" | grep -v "^$" | tail -10
echo ""

# 7. Monitorar logs em tempo real por 10 segundos
echo "================================"
echo "7. Monitorando logs em tempo real por 10 segundos..."
echo "   (aguarde para capturar novas tentativas de conexão)"
echo "================================"
timeout 10 docker logs $DATABASE_CONTAINER -f 2>&1 | grep -E "(FATAL|ERROR|connection|authentication)" || true
echo ""

echo "================================"
echo "Diagnóstico concluído!"
echo "================================"
echo ""
echo "📋 Resumo:"
echo "   - Se o webserver CONSEGUE conectar: a senha dele está correta"
echo "   - As tentativas FATAL podem ser de:"
echo "     * Monitoramento externo"
echo "     * Healthchecks do Coolify"
echo "     * Processos antigos"
echo ""
echo "🔍 Próximos passos:"
echo "   - Verifique se as senhas são iguais nos dois containers"
echo "   - Se forem diferentes, recrie o volume do banco"
echo ""
