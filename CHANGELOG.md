# Changelog - eSUS Docker

## [2025-10-12] - Correções para deploy no Coolify

### Problema identificado
- O eSUS não estava sendo instalado durante o build porque o banco de dados não estava disponível
- O `startup.sh` não estava preparado para instalar o eSUS no runtime
- As variáveis de ambiente `APP_DB_*` não estavam sendo usadas corretamente

### Alterações realizadas

#### 1. **webserver/Dockerfile**
- ✅ Adicionado `postgresql-client` para permitir verificação de conexão com banco
- ✅ Adicionado `curl` para healthchecks
- ✅ Removida instalação do eSUS durante o build (movida para runtime)
- ✅ Instalador (eSUS-AB-PEC.jar) é preservado para instalação posterior

**Antes:**
```dockerfile
RUN echo "s" | java -jar eSUS-AB-PEC.jar -console -url=${APP_DB_URL} ...
RUN rm -r /home/downloads/*  # ← Apagava o instalador
```

**Depois:**
```dockerfile
# NÃO instalar durante o build
# Preservar o JAR para instalação no startup
```

#### 2. **webserver/startup.sh** - Reescrito completamente
- ✅ Verifica se o eSUS está instalado
- ✅ Se não estiver, faz a instalação automaticamente
- ✅ Aguarda o banco de dados estar disponível antes de instalar
- ✅ Usa variáveis de ambiente `APP_DB_*` (passadas via build args)
- ✅ Fallback para ler do `application.properties` se necessário
- ✅ Logs melhorados para debug
- ✅ Tratamento de erros robusto

**Fluxo do novo startup.sh:**
1. Lê variáveis de ambiente (APP_DB_URL, APP_DB_USER, APP_DB_PASSWORD)
2. Verifica se `/opt/e-SUS/webserver/standalone.sh` existe
3. Se NÃO existe:
   - Aguarda banco de dados estar disponível
   - Instala o eSUS usando o JAR preservado
   - Extrai o migrador
4. Executa migrações do banco
5. Inicia o servidor eSUS

#### 3. **docker-compose.yaml**
- ✅ Alterado `expose: 8080` para `ports: "${WEB_PORT:-8080}:8080"`
- ✅ Porta agora é configurável via variável de ambiente `WEB_PORT`
- ✅ Permite acesso externo à aplicação

### Como usar

#### Deploy All-in-One (Recomendado para começar)

**No Coolify:**
- Docker Compose File: `docker-compose.yaml`
- Variáveis de ambiente:
  ```env
  WEB_PORT=8080
  POSTGRES_PASSWORD=SuaSenhaSegura
  ```

**O que acontece:**
1. Build baixa o instalador do eSUS (~800MB)
2. Na primeira execução, o `startup.sh` instala o eSUS
3. Instalação demora ~5-10 minutos
4. Aplicação estará disponível em `http://seu-dominio:8080`

### Benefícios das mudanças

- ✅ **Funciona no Coolify** - Instalação acontece no runtime quando o banco está disponível
- ✅ **Mais rápido no build** - Build não tenta conectar ao banco
- ✅ **Robusto** - Aguarda o banco estar pronto antes de instalar
- ✅ **Idempotente** - Pode reiniciar o container sem reinstalar
- ✅ **Logs claros** - Fácil de debugar problemas

### Tempo estimado de deploy

- **Build inicial**: ~25 minutos (download do eSUS)
- **Primeira execução**: ~5-10 minutos (instalação + migrações)
- **Reinicializações**: ~1-2 minutos (apenas startup)

### Próximos passos após deploy

1. Aguardar a primeira inicialização completa
2. Acessar `http://seu-dominio:8080`
3. Fazer login com credenciais padrão do eSUS
4. Configurar conforme necessário
