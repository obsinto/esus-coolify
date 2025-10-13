# Guia de Implantação no Coolify

## Desafio Técnico: Build vs Runtime

### O Problema
O instalador do e-SUS PEC precisa **conectar ao banco de dados durante o build da imagem** (não apenas em runtime). Isso cria um desafio porque:

- **Durante `docker build`**: Não existe rede interna do Docker Compose
- **O instalador precisa acessar o PostgreSQL** para configurar o sistema
- **Solução**: Usar `host.docker.internal` durante o build e porta exposta

### A Solução Implementada

1. **Durante o build** (webserver/Dockerfile linha 40):
   - URL: `jdbc:postgresql://host.docker.internal:5432/esus`
   - A porta 5432 está exposta temporariamente
   - `extra_hosts` mapeia `host.docker.internal` para o gateway do host

2. **Durante o runtime** (webserver/startup.sh):
   - O script substitui `host.docker.internal` por `database`
   - URL final: `jdbc:postgresql://database:5432/esus`
   - Comunicação pela rede interna do Docker

## Diferenças entre implantação local e Coolify

### Implantação Local (usando build-service.sh)
- Usa o script `build-service.sh` para orquestrar o build
- Necessita expor a porta 5432 do PostgreSQL no host
- A URL do banco é gerada dinamicamente: `jdbc:postgresql://IP_DO_HOST:5432/esus`
- Requer execução manual do script

### Implantação no Coolify (Automática)
- **NÃO usa o script `build-service.sh`**
- O Coolify gerencia todo o processo de build e deploy
- A porta 5432 NÃO é exposta (comunicação interna apenas)
- A URL do banco usa DNS interno: `jdbc:postgresql://database:5432/esus`
- Deploy automático via Git push

## Por que o build-service.sh não é usado no Coolify?

O script `build-service.sh` foi criado para resolver um problema específico do ambiente local:
- Aguardar o banco estar pronto antes de fazer build do webserver
- Gerar a URL de conexão com o IP do host

No Coolify, isso é resolvido automaticamente através de:
1. **`depends_on` com `condition: service_healthy`**: Garante que o database inicie primeiro
2. **Healthchecks**: O Coolify espera os serviços estarem saudáveis antes de considerá-los prontos
3. **Rede interna Docker**: Os serviços se comunicam pelo nome (DNS interno)

## Configuração para Coolify

### Variáveis de ambiente necessárias:

```env
POSTGRES_DB=esus
POSTGRES_USER=postgres
POSTGRES_PASSWORD=SuaSenhaSegura123
URL_DOWNLOAD_ESUS=https://arquivos.esusab.ufsc.br/PEC/26e603822f8adcc4/5.3.28/eSUS-AB-PEC-5.3.28-Linux64.jar
ESUS_TRAINING_MODE=false
```

**Sobre ESUS_TRAINING_MODE:**
- `false` (padrão): Instalação de **Produção** com dados reais
- `true`: Instalação de **Treinamento** para capacitação e testes

### O que o docker-compose.yaml faz automaticamente:

1. **Constrói a URL do banco dinamicamente**:
   ```yaml
   - APP_DB_URL=jdbc:postgresql://database:5432/${POSTGRES_DB:-esus}
   ```

2. **Garante ordem de inicialização**:
   ```yaml
   depends_on:
     database:
       condition: service_healthy
   ```

3. **Usa as mesmas credenciais para database e webserver**:
   ```yaml
   - APP_DB_USER=${POSTGRES_USER:-postgres}
   - APP_DB_PASSWORD=${POSTGRES_PASSWORD:-esus}
   ```

## Resumo

| Aspecto | Local (build-service.sh) | Coolify |
|---------|-------------------------|---------|
| Orquestração | Manual via script | Automática |
| URL do banco | IP do host | Nome do serviço (DNS) |
| Porta 5432 | Exposta | Interna apenas |
| Build | Sequencial manual | Gerenciado pelo Coolify |
| Variáveis | Exportadas no script | Configuradas na UI |

**Conclusão**: No Coolify, simplesmente faça push do código e configure as variáveis de ambiente. O Coolify cuida do resto! 🚀
