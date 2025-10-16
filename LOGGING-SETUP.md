# Configuração de Logs do e-SUS PEC

## Problema Identificado

O líder de TI do SUS reportou que os logs do webserver deveriam ser gerados no formato:
```
pec.log.2025-10-13.0.gz
```

Porém, a configuração padrão estava usando:
- `RollingFileAppender` (rotação por tamanho ao invés de data)
- Formato: `pec.log`, `pec.log.1` (sem data)
- Sem compressão `.gz`

## Causa Raiz

O e-SUS PEC utiliza **Log4j** para logging, e o arquivo `log4j.properties` original estava configurado com:

```properties
log4j.appender.file=org.apache.log4j.RollingFileAppender
log4j.appender.file.file=pec.log
log4j.appender.file.MaxFileSize=2MB
log4j.appender.file.MaxBackupIndex=1
```

Esta configuração:
- Rotaciona apenas quando atinge 2MB
- Mantém apenas 1 backup (`.1`)
- Não adiciona data ao nome do arquivo

## Solução Implementada

### 1. Novo arquivo de configuração Log4j

Criado `webserver/log4j.properties` com:

```properties
log4j.appender.file=org.apache.log4j.DailyRollingFileAppender
log4j.appender.file.file=pec.log
log4j.appender.file.DatePattern='.'yyyy-MM-dd'.'SSS
```

**Mudanças:**
- ✅ `DailyRollingFileAppender` (rotação diária)
- ✅ `DatePattern` com formato `yyyy-MM-dd.SSS`
- ✅ Formato resultante: `pec.log.2025-10-13.000`, `pec.log.2025-10-13.001`, etc.

### 2. Script de configuração automática

Criado `webserver/configure-logging.sh` que:
1. Aguarda a instalação do e-SUS estar completa
2. Localiza o arquivo `log4j.properties` da instalação
3. Faz backup do arquivo original
4. Aplica a nova configuração

### 3. Integração no processo de inicialização

**Dockerfile atualizado:**
```dockerfile
COPY startup.sh /opt
COPY configure-logging.sh /opt
RUN chmod +x /opt/startup.sh /opt/configure-logging.sh
```

**startup.sh atualizado:**
```bash
# Configurar logging após instalação
if [ -x "/opt/configure-logging.sh" ]; then
  /opt/configure-logging.sh
fi
```

## Formato de Logs Resultante

Com a configuração aplicada, os logs serão gerados como:
```
pec.log                    # Log atual
pec.log.2025-10-13.000     # Rotacionado (primeiro da data)
pec.log.2025-10-14.000     # Dia seguinte
pec.log.2025-10-14.001     # Segundo log do mesmo dia (se reiniciar)
```

## Limitação: Compressão .gz

⚠️ **IMPORTANTE:** O `DailyRollingFileAppender` do Log4j 1.x **NÃO comprime automaticamente** em `.gz`.

### Por que não comprime?

Log4j 1.x não suporta compressão automática. Apenas o Log4j 2.x tem essa funcionalidade com `RollingFileAppender` + `GzipCompressor`.

### Alternativas para Compressão

#### Opção 1: Cron job no container (Recomendado)

Adicionar no `Dockerfile`:
```dockerfile
RUN apt-get install -y cron
COPY compress-logs.sh /etc/cron.daily/
RUN chmod +x /etc/cron.daily/compress-logs.sh
```

Script `compress-logs.sh`:
```bash
#!/bin/sh
find /opt/e-SUS/webserver/standalone/log -name "pec.log.*" -type f ! -name "*.gz" -mtime +1 -exec gzip {} \;
```

#### Opção 2: Cron job no host

Se os logs estiverem mapeados no host:
```bash
# Adicionar no crontab
0 2 * * * find /caminho/logs -name "pec.log.*" ! -name "*.gz" -mtime +1 -exec gzip {} \;
```

#### Opção 3: Migrar para Log4j2

Requereria modificações no e-SUS PEC (não recomendado):
- Substituir dependências Log4j 1.x → 2.x
- Converter `log4j.properties` → `log4j2.xml`
- Testar extensivamente

## Como Aplicar as Mudanças

### 1. Rebuild do webserver

```bash
# Parar o container
docker compose stop webserver

# Remover container antigo
docker compose rm -f webserver

# Rebuild com nova configuração
docker compose build webserver

# Iniciar novamente
docker compose up -d webserver
```

### 2. Verificar aplicação

```bash
# Acompanhar logs
docker compose logs -f webserver

# Procurar pela mensagem
# "✅ Configuração de logging aplicada com sucesso!"

# Verificar arquivo configurado
docker compose exec webserver cat /opt/e-SUS/webserver/configuration/log4j.properties
```

### 3. Testar rotação

```bash
# Entrar no container
docker compose exec webserver sh

# Verificar logs
cd /opt/e-SUS/webserver/standalone/log
ls -lah pec.log*

# Deve mostrar:
# pec.log.2025-10-16.000
```

## Persistir Logs no Host

Para facilitar acesso e backup, mapear volume:

**docker-compose.yaml:**
```yaml
webserver:
  volumes:
    - ./logs:/opt/e-SUS/webserver/standalone/log
```

Rebuild:
```bash
docker compose down
docker compose up -d
```

Os logs estarão em `./logs/` no host.

## Troubleshooting

### Logs não estão rotacionando com data

**Verificar:**
1. Configuração aplicada: `docker compose exec webserver cat /opt/e-SUS/webserver/configuration/log4j.properties`
2. Localização do arquivo correto (pode variar por versão)
3. Reiniciar após mudança de configuração

### Arquivo log4j.properties não encontrado

O script `configure-logging.sh` procura automaticamente:
```bash
find /opt/e-SUS -name "log4j.properties"
```

Se não encontrar, cria em `/opt/e-SUS/webserver/configuration/log4j.properties`

### Formato diferente do esperado

O formato final depende da versão do Log4j:
- Log4j 1.x: `pec.log.2025-10-13.000`
- Esperado: `pec.log.2025-10-13.0.gz`

Diferenças:
- `.000` vs `.0` → Normal (SSS = milissegundos com 3 dígitos)
- Falta `.gz` → Requer solução adicional (cron job)

## Referências

- [Log4j 1.2 Documentation](https://logging.apache.org/log4j/1.2/)
- [DailyRollingFileAppender JavaDoc](https://logging.apache.org/log4j/1.2/apidocs/org/apache/log4j/DailyRollingFileAppender.html)
- [SimpleDateFormat patterns](https://docs.oracle.com/javase/8/docs/api/java/text/SimpleDateFormat.html)

## Arquivos Modificados

1. `webserver/log4j.properties` - Nova configuração
2. `webserver/configure-logging.sh` - Script de aplicação
3. `webserver/Dockerfile` - Copia os arquivos
4. `webserver/startup.sh` - Chama script de configuração
5. `README.md` - Documentação de uso
6. `LOGGING-SETUP.md` - Este arquivo (troubleshooting)
