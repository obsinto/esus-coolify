# eSUS-Docker
Implantando o e-SUS PEC em container Docker

## Índice
- [Implantação com Coolify (Recomendado)](#implantação-com-coolify-recomendado)
- [Implantação Manual com Docker Compose](#implantação-manual-com-docker-compose)
- [Gerando as imagens manualmente](#gerando-as-imagens-manualmente)

---

## Implantação com Coolify (Recomendado)

### Pré-requisitos
- Instância do Coolify configurada e funcionando
- Repositório Git com este projeto

### Passo a Passo

1. **No Coolify, adicione um novo recurso:**
   - Clique em "+ Add Resource"
   - Selecione "Docker Compose"
   - Conecte ao seu repositório Git

2. **Configure as variáveis de ambiente:**
   - O Coolify detectará automaticamente o `docker-compose.yml`
   - Adicione as seguintes variáveis de ambiente no painel do Coolify:

   ```env
   POSTGRES_DB=esus
   POSTGRES_USER=postgres
   POSTGRES_PASSWORD=SuaSenhaSegura123
   URL_DOWNLOAD_ESUS=https://arquivos.esusab.ufsc.br/PEC/1af9b7ee9c3886bd/5.3.21/eSUS-AB-PEC-5.3.21-Linux64.jar
   ESUS_TRAINING_MODE=false
   ```

   **Nota sobre ESUS_TRAINING_MODE:**
   - `false` (padrão): Instalação de **Produção** - para uso com dados reais
   - `true`: Instalação de **Treinamento** - para capacitação e testes

3. **Configure o domínio:**
   - No Coolify, configure um domínio para o serviço `webserver`
   - A porta padrão é `8080`

4. **Deploy:**
   - Clique em "Deploy"
   - O Coolify irá construir as imagens e iniciar os containers automaticamente
   - Aguarde alguns minutos para o primeiro build (pode levar 5-10 minutos)

### Vantagens da implantação com Coolify
- Gerenciamento automático de SSL/TLS
- Backup automático de volumes
- Rollback de deploys
- Logs centralizados
- Monitoramento integrado
- Atualizações simplificadas

---

## Implantação Manual com Docker Compose

### Usando o script de build automático

No diretório raiz do projeto execute o comando:
```bash
sudo sh build-service.sh
```

Este script irá:
1. Criar a imagem e container do banco de dados
2. Aguardar o banco de dados estar saudável
3. Criar a imagem e container do webserver
4. Aguardar o webserver estar disponível

Após a conclusão, acesse: `http://localhost:8080`

### Usando Docker Compose diretamente

1. **Copie o arquivo de exemplo de variáveis:**
```bash
cp .env.example .env
```

2. **Edite o arquivo `.env` com suas configurações**

3. **Suba os serviços:**
```bash
docker compose up -d
```

---

## Gerando as imagens manualmente

### Imagem do Banco de Dados

Entre na pasta database e execute:
```bash
sudo docker build -t esus_database:1.0.0 .
```

### Imagem do Webserver

Primeiro, obtenha o link de download da versão do e-SUS PEC em: https://sisaps.saude.gov.br/esus/

Entre na pasta webserver e execute:
```bash
sudo docker build \
  --build-arg=URL_DOWNLOAD_ESUS=https://arquivos.esusab.ufsc.br/PEC/1af9b7ee9c3886bd/5.3.21/eSUS-AB-PEC-5.3.21-Linux64.jar \
  --build-arg=APP_DB_URL=jdbc:postgresql://database:5432/esus \
  --build-arg=APP_DB_USER=postgres \
  --build-arg=APP_DB_PASSWORD=esus \
  -t esus_webserver:5.2.31 .
```

---

## Observações Importantes

- **Persistência de dados:** O volume `postgres_data` garante que os dados do banco não sejam perdidos
- **Segurança:** Altere as senhas padrão em produção
- **Portas:** Por padrão, o PostgreSQL usa a porta 5432 e o webserver a porta 8080
- **Healthchecks:** Os containers têm verificações de saúde configuradas para garantir disponibilidade
- **Restart policy:** Os containers reiniciam automaticamente em caso de falha

---

## Backup e Restauração do Banco de Dados

### Backups Automáticos (Recomendado)

O sistema está configurado para realizar backups automáticos diários **salvos diretamente no host**:

**Características:**
- ⏰ **Execução**: Todos os dias à meia-noite (00:00)
- 📦 **Retenção**: Configurável via `BACKUP_RETENTION_DAYS` (padrão: 7 dias)
- 💾 **Localização no host**: Configurável via `BACKUP_DIR` (padrão: `./backups`)
- 🗑️ **Limpeza automática**: Remove backups mais antigos que RETENTION_DAYS
- 📋 **Logs**: Disponíveis em `/var/log/cron.log` no container

**Configuração no `.env` ou Coolify:**
```env
# Diretório no host onde salvar backups (relativo ou absoluto)
BACKUP_DIR=./backups

# Número de dias para manter backups (mais antigos são removidos)
BACKUP_RETENTION_DAYS=7
```

**Exemplos de BACKUP_DIR:**
```env
# Caminho relativo (dentro do diretório do projeto)
BACKUP_DIR=./backups

# Caminho absoluto no VPS/host
BACKUP_DIR=/mnt/storage/esus-backups

# No Coolify, pode usar um volume persistente
BACKUP_DIR=/data/coolify/backups/esus
```

**Verificar backups no host:**
```bash
# Listar backups (diretamente no host)
ls -lh ./backups/

# Ver dentro do container (mesmo diretório via bind mount)
docker compose exec database ls -lh /backups

# Ver logs dos backups
docker compose exec database cat /var/log/cron.log

# Verificar se o cron está rodando
docker compose exec database ps | grep crond
```

**Executar backup manual:**
```bash
docker compose exec database /usr/local/bin/backup.sh
```

**Acesso aos backups:**

Os backups ficam **diretamente acessíveis no host** no diretório configurado (padrão `./backups`), não sendo necessário copiar do container. Você pode:
- Fazer backup deles para outro servidor
- Sincronizar com cloud (AWS S3, Google Drive, etc)
- Acessar via SFTP/SCP
- Incluir em backup de sistema

**Desabilitar backups automáticos:**

Se você NÃO quiser backups automáticos, comente a linha no `database/Dockerfile`:
```dockerfile
# COPY init-cron.sh /docker-entrypoint-initdb.d/init-cron.sh
```

---

### Backups Automáticos para S3 (AWS/MinIO/Wasabi)

O sistema suporta envio automático de backups para **Amazon S3** ou serviços compatíveis (MinIO, Wasabi, DigitalOcean Spaces, etc).

**Pré-requisitos:**

1. **Habilitar AWS CLI** no `database/Dockerfile` (descomente as linhas 9-12):
```dockerfile
# Antes (comentado):
# RUN apk add --no-cache python3 py3-pip && \
#     pip3 install --upgrade pip && \
#     pip3 install awscli && \
#     rm -rf /var/cache/apk/*

# Depois (descomentado):
RUN apk add --no-cache python3 py3-pip && \
    pip3 install --upgrade pip && \
    pip3 install awscli && \
    rm -rf /var/cache/apk/*
```

2. **Configurar variáveis de ambiente** no `.env` ou Coolify:

**Para AWS S3:**
```env
# Bucket S3
S3_BUCKET=meu-bucket-esus-backups

# Região AWS
AWS_DEFAULT_REGION=us-east-1

# Credenciais AWS (crie um usuário IAM com permissões s3:PutObject, s3:GetObject, s3:DeleteObject)
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

**Para serviços S3-compatible (MinIO, Wasabi, etc):**
```env
S3_BUCKET=meu-bucket
AWS_DEFAULT_REGION=us-east-1
AWS_ACCESS_KEY_ID=sua_access_key
AWS_SECRET_ACCESS_KEY=sua_secret_key

# Endpoint customizado (obrigatório para serviços não-AWS)
AWS_ENDPOINT_URL=https://s3.wasabisys.com
# ou para MinIO local: http://minio:9000
```

**Como funciona:**

1. Backup é criado localmente em `/backups` (host)
2. Se `S3_BUCKET` estiver configurado, o backup é automaticamente enviado para S3
3. Backups antigos são removidos **tanto no host quanto no S3** respeitando `BACKUP_RETENTION_DAYS`
4. Logs mostram o status do upload: `docker compose exec database cat /var/log/cron.log`

**Exemplo de log com S3:**
```
=== Iniciando backup automático ===
✅ Backup criado com sucesso: /backups/backup_2025_01_15__00_00_00.backup
Tamanho do backup: 245M

=== Enviando backup para S3 ===
Bucket: meu-bucket-esus-backups
Região: us-east-1
✅ Backup enviado para S3: s3://meu-bucket-esus-backups/esus-backups/backup_2025_01_15__00_00_00.backup

=== Limpando backups antigos no S3 ===
Removendo backup antigo do S3: backup_2025_01_08__00_00_00.backup
```

**Permissões IAM necessárias (AWS):**

Crie um usuário IAM com esta política:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::meu-bucket-esus-backups",
        "arn:aws:s3:::meu-bucket-esus-backups/*"
      ]
    }
  ]
}
```

**Restaurar backup do S3:**
```bash
# Listar backups no S3
aws s3 ls s3://meu-bucket-esus-backups/esus-backups/

# Baixar backup específico
aws s3 cp s3://meu-bucket-esus-backups/esus-backups/backup_2025_01_15__00_00_00.backup ./

# Copiar para o container e restaurar
docker compose cp backup_2025_01_15__00_00_00.backup database:/tmp/
docker compose exec database pg_restore -U "postgres" -d "esus" -c /tmp/backup_2025_01_15__00_00_00.backup
```

**Rebuild necessário:**

Após descomentar as linhas do AWS CLI no Dockerfile, faça rebuild:
```bash
docker compose down database
docker compose build database
docker compose up -d database
```

---

### Criando backups manuais

**Backup do banco PostgreSQL (formato custom - recomendado):**
```bash
docker compose exec database bash -c 'pg_dump --host localhost --port 5432 -U "postgres" --format custom --blobs --encoding UTF8 --no-privileges --no-tablespaces --no-unlogged-table-data --file "/var/lib/postgresql/data/backup_$(date +"%Y_%m_%d__%H_%M_%S").backup" "esus"'
```

**Backup em formato SQL (alternativa):**
```bash
docker compose exec database bash -c 'pg_dump -U "postgres" "esus" > /var/lib/postgresql/data/backup_$(date +"%Y_%m_%d__%H_%M_%S").sql'
```

**Copiar backup para o host:**
```bash
docker compose cp database:/var/lib/postgresql/data/backup_YYYY_MM_DD__HH_MM_SS.backup ./backup_YYYY_MM_DD__HH_MM_SS.backup
```

### Restaurando um backup

**Restaurar backup automático:**
```bash
# Listar backups disponíveis
docker compose exec database ls -lh /backups

# Restaurar um backup específico
docker compose exec database pg_restore -U "postgres" -d "esus" -c /backups/backup_YYYY_MM_DD__HH_MM_SS.backup
```

**Restaurar backup manual formato custom:**
```bash
docker compose exec database bash -c 'pg_restore -U "postgres" -d "esus" -c /var/lib/postgresql/data/seu_arquivo.backup'
```

**Restaurar backup formato SQL:**
```bash
docker compose exec database bash -c 'psql -U "postgres" "esus" < /var/lib/postgresql/data/seu_arquivo.sql'
```

---

## Migração e Atualização de Versão do e-SUS PEC

### Verificação de Persistência dos Dados

Antes de qualquer atualização, verifique se o volume do banco de dados está persistindo corretamente:

```bash
# Verificar volumes Docker
docker volume ls | grep postgres

# Inspecionar o volume
docker volume inspect esus-docker_postgres_data

# Verificar o tamanho do volume (deve ter dados)
docker compose exec database bash -c 'du -sh /var/lib/postgresql/data'
```

### Processo de Atualização Segura

**Importante:** Segundo a equipe do e-SUS PEC, a migração do banco de dados em Linux pode ter menos verificações que no Windows. Sempre faça backup antes de atualizar.

#### Passo 1: Criar backup completo

```bash
# Criar backup do banco de dados
docker compose exec database bash -c 'pg_dump --host localhost --port 5432 -U "postgres" --format custom --blobs --encoding UTF8 --no-privileges --no-tablespaces --no-unlogged-table-data --file "/var/lib/postgresql/data/backup_pre_update_$(date +"%Y_%m_%d__%H_%M_%S").backup" "esus"'

# Copiar backup para o host
docker compose cp database:/var/lib/postgresql/data/backup_pre_update_*.backup ./
```

#### Passo 2: Verificar a versão atual

```bash
# Ver logs do container para identificar a versão instalada
docker compose logs webserver | grep -i "versão\|version"
```

#### Passo 3: Atualizar para nova versão

1. **Obtenha o link da nova versão** em: https://sisaps.saude.gov.br/esus/

2. **Atualize a variável de ambiente:**
   - No Coolify: Edite a variável `URL_DOWNLOAD_ESUS` na interface
   - Local: Edite o arquivo `.env`

   ```env
   URL_DOWNLOAD_ESUS=https://arquivos.esusab.ufsc.br/PEC/nova_versao/eSUS-AB-PEC-X.X.XX-Linux64.jar
   ```

3. **Para instalação local:**
   ```bash
   # Parar o webserver
   docker compose stop webserver

   # Remover o container antigo (não remove o volume)
   docker compose rm -f webserver

   # Rebuild com a nova versão
   docker compose build webserver

   # Iniciar o webserver
   docker compose up -d webserver
   ```

4. **Para Coolify:**
   - Faça commit das alterações no Git
   - Faça push para o repositório
   - Ou clique em "Redeploy" no Coolify após alterar a variável

#### Passo 4: Acompanhar a migração

```bash
# Acompanhar logs em tempo real
docker compose logs -f webserver

# Procurar por mensagens de migração
docker compose logs webserver | grep -i "migra\|atualiz\|update"
```

A migração do banco acontece automaticamente através do `migrador.jar` (webserver/startup.sh:118-126)

#### Passo 5: Validar a atualização

```bash
# Verificar se o webserver está saudável
docker compose ps

# Testar acesso à aplicação
curl -I http://localhost:8080

# Verificar logs por erros
docker compose logs webserver | grep -i "error\|erro"
```

### Em caso de problemas na atualização

Se a migração falhar ou houver problemas:

```bash
# Parar todos os serviços
docker compose down

# Restaurar o backup
docker compose up -d database

# Aguardar o banco estar pronto
sleep 10

# Restaurar o backup (substituir o nome do arquivo)
docker compose exec database bash -c 'pg_restore -U "postgres" -d "esus" -c /var/lib/postgresql/data/backup_pre_update_*.backup'

# Reverter para a versão anterior no .env
# Depois rebuildar o webserver com a versão antiga
docker compose build webserver
docker compose up -d webserver
```

### Testado com sucesso

- ✅ Migração de 4.2.6 para 4.5.5
- ✅ Migração de 5.2.x para 5.3.x

---

## Solução de Problemas

### Container do banco não inicia
```bash
docker compose logs database
```

### Container do webserver não inicia
```bash
docker compose logs webserver
```

### Resetar completamente o ambiente
```bash
docker compose down -v
docker compose up -d
```
