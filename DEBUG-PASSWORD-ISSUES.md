# Debug: Password Authentication Failed

## Sintoma
Logs do database mostram:
```
FATAL:  password authentication failed for user "postgres"
```

Mas a aplicação está funcionando.

## Causa provável

O volume do PostgreSQL foi criado com uma senha, mas você mudou a senha depois.

### O PostgreSQL só define a senha na PRIMEIRA inicialização

Quando o volume `postgres_data` já existe:
- `POSTGRES_PASSWORD` é **IGNORADO**
- O banco usa a senha que foi definida na primeira vez

## Soluções

### Solução 1: Recriar o banco (PERDE DADOS!)

⚠️ **ATENÇÃO**: Isso apaga todos os dados do banco!

**No Coolify:**
1. Vá no recurso do eSUS
2. Stop o recurso
3. Delete o volume `postgres_data`
4. Faça Redeploy

**Via SSH:**
```bash
# Ver volumes
docker volume ls | grep postgres

# Deletar volume específico
docker volume rm bgkog044wgck84csoookg444_postgres_data

# Redeploy no Coolify
```

### Solução 2: Alterar a senha do banco manualmente

**Se você quer manter os dados:**

```bash
# 1. Entre no container do banco
docker exec -it database-xxxxx psql -U postgres

# 2. Altere a senha para a que está no docker-compose
ALTER USER postgres WITH PASSWORD 'esus';

# ou para a senha que você configurou:
ALTER USER postgres WITH PASSWORD 'SuaSenhaSegura123';

# 3. Saia
\q
```

Depois, **atualize a variável de ambiente no Coolify** para corresponder:
```env
POSTGRES_PASSWORD=esus
```

Ou a senha que você definiu.

### Solução 3: Ignorar (se não incomoda)

Se a aplicação está funcionando:
- O webserver está usando a senha **correta**
- Essas tentativas falhas podem ser de:
  - Monitoramento do Coolify
  - Healthchecks
  - Tentativas externas

**Não afeta o funcionamento**, mas fica poluindo os logs.

## Como descobrir quem está tentando conectar

**Entre no servidor via SSH:**

```bash
# Ver logs detalhados do PostgreSQL
docker logs database-xxxxx -f

# Ver conexões ativas
docker exec -it database-xxxxx psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Ver tentativas de conexão (requer configuração)
docker exec -it database-xxxxx psql -U postgres -c "SHOW log_connections;"
```

## Prevenção

### Use sempre a mesma senha desde o início

**No Coolify, defina antes do primeiro deploy:**
```env
POSTGRES_PASSWORD=MinHaSenhaSegura123
WEB_PORT=8081
```

### Ou use a senha padrão

Se não configurar nada, usa `esus` (default do docker-compose.yaml).

## Verificar qual senha está funcionando

```bash
# Entre no container do webserver
docker exec -it webserver-xxxxx sh

# Ver variáveis de ambiente
echo $APP_DB_PASSWORD

# Tentar conectar
PGPASSWORD=$APP_DB_PASSWORD psql -h database -U postgres -d esus -c "SELECT 1"
```

Se funcionar, essa é a senha correta. Anote ela!

## Sincronizar senhas

Garanta que **todos** usam a mesma senha:

**docker-compose.yaml:**
```yaml
database:
  environment:
    - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-esus}

webserver:
  environment:
    - APP_DB_PASSWORD=${POSTGRES_PASSWORD:-esus}  # ← Mesma variável!
```

**No Coolify:**
```env
POSTGRES_PASSWORD=MinHaSenhaUnica123
```

Ambos os serviços usarão a mesma senha.
