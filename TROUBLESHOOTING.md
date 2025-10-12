# Troubleshooting - eSUS no Coolify

## Como verificar se está funcionando

### 1. Logs do Database
No Coolify, vá no recurso → Logs do container `database`

**Deve mostrar:**
```
database system is ready to accept connections
```

### 2. Logs do Webserver
No Coolify, vá no recurso → Logs do container `webserver`

**Deve mostrar:**
```
Database URL = jdbc:postgresql://database:5432/esus
Username = postgres
Instalação inicial do e-SUS...
```

## Problemas comuns

### Erro: "Connection refused" nos logs do webserver

**Causa**: Webserver tentando conectar antes do banco estar pronto

**Solução**: O `depends_on` com `condition: service_healthy` já resolve isso. Aguarde alguns segundos.

### Erro: "Authentication failed"

**Causa**: Senha do banco incorreta

**Solução**: Verifique as variáveis de ambiente:
- `POSTGRES_PASSWORD` deve ser a mesma em ambos os serviços
- Se alterou a senha, faça redeploy completo

### Aplicação não responde na porta

**Verificar**:
1. Qual porta está configurada? Veja a variável `WEB_PORT`
2. No Coolify, vá em **Domains/Ports** e confirme que a porta está exposta
3. Teste localmente no servidor:
   ```bash
   curl http://localhost:8080
   ```

### Primeira inicialização muito lenta

**É normal!** A primeira vez demora porque:
- Instala o eSUS (se não instalou no build)
- Cria todo o schema do banco
- Executa migrações do Liquibase
- Pode demorar 5-10 minutos

**Acompanhe os logs** para ver o progresso.

### Erro de migração do Liquibase

Se aparecer:
```
Liquibase lock
```

**Solução**: Entre no container do banco e limpe o lock:
```bash
docker exec -it database-xxxxx psql -U postgres -d esus
DELETE FROM databasechangeloglock WHERE locked = true;
\q
```

Depois reinicie o webserver.

## Comandos úteis

### Entrar no container do banco
```bash
docker exec -it database-xxxxx psql -U postgres -d esus
```

### Ver tabelas criadas
```sql
\dt
```

### Ver logs do webserver em tempo real
No Coolify: Recurso → Logs → Habilitar "Auto-refresh"

### Reiniciar apenas o webserver
No Coolify: Recurso → Containers → webserver → Restart

### Fazer backup do banco
```bash
docker exec -t database-xxxxx pg_dump -U postgres esus > backup.sql
```

## Informações importantes

- **Porta interna do eSUS**: 8080
- **Porta do PostgreSQL**: 5432
- **Usuário padrão**: postgres
- **Banco de dados**: esus
- **Diretório de dados do eSUS**: `/opt/e-SUS` (volume persistente)
- **Diretório de dados do PostgreSQL**: `/var/lib/postgresql/data` (volume persistente)
