# Deploy Rápido no Coolify (Versão Simplificada)

## Passo 1: Criar PostgreSQL no Coolify
1. No Coolify: **+ Add** → **Database** → **PostgreSQL**
2. Anote a URL de conexão que o Coolify fornece

## Passo 2: Extrair informações da URL

Se a URL é:
```
postgres://postgres:SENHA@HOST:5432/postgres
```

Extraia:
- **HOST**: A parte entre `@` e `:5432`
- **USER**: `postgres`
- **PASSWORD**: A senha longa
- **DATABASE**: `postgres` (ou crie um banco `esus`)

## Passo 3: Deploy da Aplicação

1. No Coolify: **+ Add** → **Docker Compose**
2. Repositório: Seu repositório Git
3. **Docker Compose File**: `docker-compose.coolify.yaml`
4. **Environment Variables**:

```env
APP_DB_URL=jdbc:postgresql://HOST:5432/postgres
APP_DB_USER=postgres
APP_DB_PASSWORD=SENHA_DO_BANCO
WEB_PORT=8081
```

**Exemplo real**:
```env
APP_DB_URL=jdbc:postgresql://skg8ooo4oc4g40wco8cwo880:5432/postgres
APP_DB_USER=postgres
APP_DB_PASSWORD=N9PINnleqtJPZba4m4gpU5fPTA8Fgp7Qb9gpuDzFsqsWiU39nWM74Gd3f1KiWQHS
WEB_PORT=8081
```

5. Clique em **Deploy**

## Passo 4: Aguardar
- Primeira instalação demora ~5-10 minutos
- Acompanhe os logs no Coolify

## Pronto!
Acesse: `http://seu-dominio:8081`

---

## Se der erro de conexão com banco:

### Opção 1: Verificar se ambos estão no mesmo servidor
No Coolify, certifique-se que banco e app estão no mesmo servidor.

### Opção 2: Criar banco `esus` (recomendado)

Entre no PostgreSQL via terminal do Coolify:
```bash
docker exec -it <container-postgres> psql -U postgres
```

Crie o banco:
```sql
CREATE DATABASE esus;
\q
```

Atualize a variável:
```env
APP_DB_URL=jdbc:postgresql://HOST:5432/esus
```

---

## Diferença entre os arquivos:

- **docker-compose.yaml**: Para uso local (banco + app tudo junto)
- **docker-compose.app.yaml**: App separada (mais complexo)
- **docker-compose.coolify.yaml**: Versão SIMPLIFICADA para Coolify (USE ESTE!)

O arquivo `docker-compose.coolify.yaml` remove tudo que não é necessário:
- Sem healthcheck complexo
- Sem configuração de rede
- Mínimo de configuração
- Foco em funcionar no Coolify
