# Usar Banco de Dados Externo do Coolify

Este guia mostra como usar um banco PostgreSQL criado pelo Coolify ao invés do banco local.

## Vantagens do Banco Externo

✅ **Banco gerenciado pelo Coolify**
- Interface gráfica para gerenciar
- Backups automáticos configuráveis
- Métricas e monitoramento
- Escalabilidade independente

✅ **Múltiplas instâncias**
- Vários ambientes (dev, staging, prod) usando o mesmo banco
- Ou bancos separados por ambiente

✅ **Facilita manutenção**
- Atualizações sem afetar a aplicação
- Restauração de backups independente

---

## Como usar

### Passo 1: Criar PostgreSQL no Coolify

1. **No Coolify**: + Add → Database → PostgreSQL
2. **Configure**:
   - Name: `esus-database` (ou o nome que preferir)
   - Version: PostgreSQL 16 (ou versão desejada)
3. **Após criar**, anote a **Connection URL**:
   ```
   postgres://postgres:SENHA@HOST:5432/postgres
   ```

Exemplo real:
```
postgres://postgres:tji8Yg4ztzp19gV2ceVdjvaXhsESaX7MLQMuN1ZObvVUg4Ev72NcIDFP8bYmbVXb@rcs8ogo4cwcos44kk0gwgkog:5432/postgres
```

---

### Passo 2: Deploy da Aplicação (Opção mais fácil)

**No Coolify:**
1. Create Resource → Docker Compose
2. Repository: Seu repositório Git
3. **Docker Compose File**: `docker-compose.external-db.yaml`
4. **Environment Variables**:

```env
# Cole a URL completa do Coolify (o script converte automaticamente!)
POSTGRES_URL=postgres://postgres:tji8Yg4ztzp19gV2ceVdjvaXhsESaX7MLQMuN1ZObvVUg4Ev72NcIDFP8bYmbVXb@rcs8ogo4cwcos44kk0gwgkog:5432/postgres

# Opcional: Domínio para acesso sem porta
DOMAIN=esus.seudominio.com.br
```

5. **Deploy**

**Pronto!** O script vai:
- ✅ Converter automaticamente a URL PostgreSQL para JDBC
- ✅ Extrair usuário e senha
- ✅ Conectar ao banco externo

---

### Passo 2: Alternativa - Configuração Manual (Opção avançada)

Se preferir controle total, configure manualmente:

**Extrair informações da URL:**
```
postgres://postgres:SENHA@HOST:5432/postgres
           ↓        ↓      ↓    ↓    ↓
         USER   PASSWORD  HOST PORT DATABASE
```

**Exemplo:**
```
postgres://postgres:tji8Yg4ztzp19gV2@rcs8ogo4cwcos44kk0gwgkog:5432/postgres

USER: postgres
PASSWORD: tji8Yg4ztzp19gV2ceVdjvaXhsESaX7MLQMuN1ZObvVUg4Ev72NcIDFP8bYmbVXb
HOST: rcs8ogo4cwcos44kk0gwgkog
PORT: 5432
DATABASE: postgres
```

**No Coolify, configure:**
```env
APP_DB_URL=jdbc:postgresql://rcs8ogo4cwcos44kk0gwgkog:5432/postgres
APP_DB_USER=postgres
APP_DB_PASSWORD=tji8Yg4ztzp19gV2ceVdjvaXhsESaX7MLQMuN1ZObvVUg4Ev72NcIDFP8bYmbVXb
DOMAIN=esus.seudominio.com.br
```

---

## Comparação: Banco Local vs Externo

### docker-compose.yaml (Banco Local)

**Uso**: Banco e aplicação no mesmo recurso

**Pros:**
- ✅ Simples, tudo em um lugar
- ✅ Não precisa configurar conexão

**Contras:**
- ❌ Banco e app acoplados
- ❌ Backups mais difíceis
- ❌ Não compartilha banco entre ambientes

**Variáveis necessárias:**
```env
WEB_PORT=8080
POSTGRES_PASSWORD=SuaSenha123
```

---

### docker-compose.external-db.yaml (Banco Externo)

**Uso**: Aplicação conecta a banco PostgreSQL do Coolify

**Pros:**
- ✅ Banco gerenciado pelo Coolify
- ✅ Backups automáticos
- ✅ Compartilha banco entre ambientes
- ✅ Escalabilidade independente

**Contras:**
- ❌ Precisa criar banco separadamente

**Variáveis necessárias:**
```env
POSTGRES_URL=postgres://user:pass@host:5432/db
DOMAIN=esus.seudominio.com.br
```

---

## Exemplos de uso

### Exemplo 1: Ambiente único (desenvolvimento)

```env
# Usar banco local (docker-compose.yaml)
WEB_PORT=8080
POSTGRES_PASSWORD=dev123
```

### Exemplo 2: Múltiplos ambientes (staging + prod)

**Recurso 1: eSUS Staging**
```env
# docker-compose.external-db.yaml
POSTGRES_URL=postgres://postgres:senha1@db-staging:5432/esus_staging
DOMAIN=staging.esus.com.br
```

**Recurso 2: eSUS Prod**
```env
# docker-compose.external-db.yaml
POSTGRES_URL=postgres://postgres:senha2@db-prod:5432/esus_prod
DOMAIN=esus.com.br
```

Ambos os recursos compartilham o mesmo código, mas bancos diferentes!

---

## Criar banco dedicado "esus" (Recomendado)

Por padrão, o PostgreSQL do Coolify cria apenas o banco `postgres`. Recomendo criar um banco dedicado `esus`:

### Via terminal do PostgreSQL no Coolify:

```sql
-- Entrar no PostgreSQL
psql -U postgres

-- Criar banco dedicado
CREATE DATABASE esus;

-- Verificar
\l

-- Sair
\q
```

### Depois, atualize a URL:

**De:**
```
postgres://postgres:SENHA@HOST:5432/postgres
```

**Para:**
```
postgres://postgres:SENHA@HOST:5432/esus
```

---

## Troubleshooting

### Erro: "Connection refused" ou "Unknown host"

**Causa**: Host incorreto ou recursos em servidores diferentes

**Solução**:
1. Certifique-se que banco e app estão no mesmo servidor Coolify
2. Verifique o host na URL do banco (copie exatamente como o Coolify fornece)

### Erro: "Authentication failed"

**Causa**: Senha incorreta

**Solução**:
1. No Coolify, vá no banco PostgreSQL
2. Copie novamente a Connection URL completa
3. Cole exatamente como está (incluindo caracteres especiais)

### Erro: "Database does not exist"

**Causa**: Banco `esus` não foi criado

**Solução**:
1. Use `postgres` (banco padrão): `.../postgres`
2. Ou crie o banco `esus` (veja seção acima)

### Logs mostram "JDBC URL: null"

**Causa**: Variável `POSTGRES_URL` não configurada

**Solução**:
```env
# Certifique-se de configurar no Coolify:
POSTGRES_URL=postgres://user:pass@host:5432/db
```

---

## Migração de Banco Local → Externo

Se você já tem dados no banco local e quer migrar:

### 1. Fazer backup do banco local:

```bash
# No container do banco local
docker exec -t database-xxxxx pg_dump -U postgres esus > backup.sql
```

### 2. Criar banco externo no Coolify

### 3. Restaurar backup no banco externo:

```bash
# Copiar backup para o servidor
scp backup.sql servidor:/tmp/

# Restaurar no banco externo
PGPASSWORD='senha-do-banco-externo' psql -h host-externo -U postgres -d esus < /tmp/backup.sql
```

### 4. Atualizar docker-compose para usar banco externo

### 5. Redeploy

---

## Verificar conexão

### No terminal do webserver:

```bash
echo "URL: $POSTGRES_URL"
echo "DB_URL gerado: $APP_DB_URL"

# Testar conexão
psql "$POSTGRES_URL" -c "SELECT version();"
```

---

## Resumo rápido

### Banco Local (mais simples):
```yaml
Arquivo: docker-compose.yaml
Variáveis: WEB_PORT, POSTGRES_PASSWORD
```

### Banco Externo (produção):
```yaml
Arquivo: docker-compose.external-db.yaml
Variáveis: POSTGRES_URL, DOMAIN
```

**Cole a URL completa do Coolify e pronto!** 🚀
