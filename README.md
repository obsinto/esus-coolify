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
   ```

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

## Atualizando para nova versão do e-SUS

1. Atualize a variável `URL_DOWNLOAD_ESUS` com o link da nova versão
2. Execute novamente o build:
```bash
docker compose build webserver
docker compose up -d webserver
```

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
