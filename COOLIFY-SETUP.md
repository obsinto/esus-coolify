# Configuração no Coolify - Banco de Dados Gerenciado

Este guia mostra como configurar o eSUS-Docker no Coolify usando o PostgreSQL gerenciado pelo painel do Coolify.

## Arquitetura

- **Recurso 1**: PostgreSQL (criado pelo painel do Coolify)
- **Recurso 2**: Aplicação eSUS (usando `docker-compose.app.yaml`)

## Vantagens dessa abordagem

- Banco de dados totalmente gerenciado pelo Coolify
- Interface gráfica para gerenciar o banco
- Backups automáticos (se configurado)
- Métricas e monitoramento integrados
- Não precisa de docker-compose para o banco
- Escalabilidade simplificada

---

## Passo 1: Criar o Banco de Dados PostgreSQL

### 1.1 No Coolify, adicione um novo recurso:
- Clique em **+ Add** ou **New Resource**
- Selecione **Database**
- Escolha **PostgreSQL**

### 1.2 Configurações do banco:
- **Name**: `esus-database` (ou o nome que preferir)
- **Version**: Escolha a versão mais recente estável (ex: PostgreSQL 16 ou 15)

### 1.3 Configurações iniciais:
Após criar o banco, configure:

**Database Configuration:**
- **Database Name**: `esus`
- **Username**: `postgres` (ou crie um usuário específico)
- **Password**: Defina uma senha forte (será usada pela aplicação)

### 1.4 Anote as informações de conexão:

Após a criação, o Coolify fornecerá:
- **Internal URL**: Algo como `postgresql-xxxxx:5432`
- **Database Name**: `esus`
- **Username**: `postgres`
- **Password**: A senha que você definiu

**IMPORTANTE**: Copie o **Internal URL** (ou Internal Domain). Você vai precisar dele!

Exemplo: `postgresql-abc123xyz:5432`

---

## Passo 2: Criar o Recurso da Aplicação eSUS

### 2.1 No Coolify, crie um novo recurso:
- Tipo: **Docker Compose**
- Nome: `esus-app`
- Repositório: Seu repositório Git
- Branch: `main` (ou sua branch)

### 2.2 Configurações do recurso:
- **Docker Compose File**: `docker-compose.app.yaml`

### 2.3 Variáveis de Ambiente OBRIGATÓRIAS:

No Coolify, vá em **Environment Variables** e adicione:

```env
# URL de conexão com o banco de dados do Coolify
# Substitua 'postgresql-xxxxx' pelo Internal Domain do seu banco
APP_DB_URL=jdbc:postgresql://postgresql-xxxxx:5432/esus

# Credenciais do banco (use as mesmas do Passo 1)
APP_DB_USER=postgres
APP_DB_PASSWORD=SuaSenhaSeguraAqui

# Porta externa da aplicação web
WEB_PORT=8081
```

**Como montar o APP_DB_URL:**
```
jdbc:postgresql://[INTERNAL_DOMAIN]:[PORTA]/[DATABASE_NAME]
```

Exemplo completo:
```
jdbc:postgresql://postgresql-abc123xyz:5432/esus
```

### 2.4 Deploy:
- Clique em **Deploy**
- Aguarde o build e inicialização
- Verifique os logs para confirmar a conexão com o banco

---

## Passo 3: Verificar a Conexão

### 3.1 Verificar logs da aplicação:

No recurso `esus-app` no Coolify:
- Vá em **Logs**
- Procure por mensagens como:
  ```
  Database URL = jdbc:postgresql://postgresql-xxxxx:5432/esus
  Username = postgres
  ```
- Se houver erro de conexão, verifique as credenciais

### 3.2 Testar acesso à aplicação:

- A aplicação estará disponível na porta configurada
- Acesse: `http://seu-dominio:8081` ou o domínio configurado no Coolify
- A primeira inicialização pode demorar alguns minutos

---

## Encontrando o Internal Domain do Banco

Se você não anotou o internal domain do banco:

1. No Coolify, vá no recurso do **PostgreSQL**
2. Procure por **Connection Details** ou **Configuration**
3. Copie o **Internal URL** ou **Internal Domain**
4. Formato: `postgresql-[ID]:5432`

Exemplo: `postgresql-r8g7f6d5:5432`

---

## Troubleshooting

### Erro: "Connection refused" ou "Connection timeout"

**Causa**: A aplicação não consegue se conectar ao banco.

**Solução**:
1. Verifique se o banco de dados está rodando (Status: Running no Coolify)
2. Confirme que o **Internal Domain** está correto em `APP_DB_URL`
3. Verifique se as credenciais estão corretas
4. Certifique-se de que ambos os recursos estão no **mesmo servidor** do Coolify

### Erro: "Authentication failed for user postgres"

**Causa**: Senha incorreta.

**Solução**:
1. No Coolify, vá no recurso do banco de dados
2. Verifique a senha configurada
3. Atualize a variável `APP_DB_PASSWORD` na aplicação
4. Faça redeploy da aplicação

### Erro: "Port 8081 already allocated"

**Causa**: Porta já está em uso.

**Solução**:
1. Altere a variável `WEB_PORT` para outra porta (ex: 8082, 9000)
2. Faça redeploy

### A aplicação demora muito para iniciar

**Causa**: Primeira execução instala o eSUS e cria o schema do banco.

**Solução**:
- Aguarde 5-10 minutos na primeira vez
- Monitore os logs para acompanhar o progresso
- Procure por mensagens de instalação do eSUS

---

## Configuração Alternativa: Deploy Único (Tudo em um)

Se preferir manter banco e aplicação no mesmo recurso Docker Compose:

**Use o arquivo original**: `docker-compose.yaml`

No Coolify:
- **Docker Compose File**: `docker-compose.yaml`
- **Variável de ambiente**:
  ```
  WEB_PORT=8081
  ```

Essa abordagem é mais simples, mas menos flexível para escalabilidade.

---

## Exemplo de Configuração Completa

### Recurso 1: PostgreSQL (Painel do Coolify)
```
Name: esus-database
Type: PostgreSQL
Version: 16
Database: esus
User: postgres
Password: MinHaSenH@Segur@123
Internal Domain: postgresql-r8g7f6d5:5432
```

### Recurso 2: Application (Docker Compose)
```yaml
Docker Compose File: docker-compose.app.yaml

Environment Variables:
APP_DB_URL=jdbc:postgresql://postgresql-r8g7f6d5:5432/esus
APP_DB_USER=postgres
APP_DB_PASSWORD=MinHaSenH@Segur@123
WEB_PORT=8081
```

---

## Backup do Banco de Dados

O Coolify oferece funcionalidades de backup para bancos de dados gerenciados:

1. No recurso do **PostgreSQL**
2. Vá em **Backups**
3. Configure backups automáticos
4. Defina frequência e retenção

### Backup manual via CLI:
```bash
# No servidor do Coolify
docker exec -t postgresql-xxxxx pg_dump -U postgres esus > backup-$(date +%Y%m%d).sql
```

---

## Acesso à Aplicação

Após o deploy bem-sucedido:
- Aplicação: `http://seu-dominio:8081` (ou porta configurada)
- Banco de dados: Acessível apenas internamente (mais seguro)
- Gerenciamento do banco: Pelo painel do Coolify

---

## Monitoramento

No Coolify você pode monitorar:
- **Logs em tempo real** de ambos os recursos
- **Métricas de CPU e memória**
- **Status dos containers**
- **Conexões do banco de dados**

Acesse cada recurso e use as abas:
- **Logs**: Ver logs em tempo real
- **Metrics**: Gráficos de uso
- **Terminal**: Acessar o container diretamente
