# eSUS PEC - Docker para Coolify

Deploy do eSUS PEC usando Docker Compose no Coolify.

## 📋 Requisitos

- Coolify instalado
- Acesso ao servidor via Coolify
- Domínio configurado (opcional)

---

## 🚀 Como usar

Este projeto suporta **duas formas de deploy**:

### Opção 1: Banco Local (Tudo junto) ✅ Mais Simples

Banco de dados e aplicação no mesmo docker-compose.

**1. Descomente o serviço `database` no `docker-compose.yaml`**

Linhas 8-23, 49-51 e 62-64

**2. No Coolify, configure:**
```env
DOMAIN=esus.seudominio.com.br
POSTGRES_PASSWORD=SuaSenhaSegura123
```

**3. Deploy!**

---

### Opção 2: Banco Externo (PostgreSQL do Coolify) 🔗 Produção

Banco de dados gerenciado separadamente pelo Coolify. **(Configuração atual)**

**1. Crie PostgreSQL no Coolify**
   - Add Resource → Database → PostgreSQL
   - Anote o nome do container (ex: `rcs8ogo4cwcos44kk0gwgkog`)

**2. No recurso da aplicação, linke o banco**
   - Vá em "Storages & Databases" ou "Connected Services"
   - Adicione/Linke o PostgreSQL criado

**3. Configure as variáveis** (banco já comentado no docker-compose.yaml):
```env
DOMAIN=esus.seudominio.com.br
APP_DB_URL=jdbc:postgresql://rcs8ogo4cwcos44kk0gwgkog:5432/postgres
APP_DB_USER=postgres
APP_DB_PASSWORD=SenhaDoPostgreSQL
```

**4. Deploy!**

---

## ⚙️ Variáveis de Ambiente

### Banco Local (Opção 1):
```env
DOMAIN=esus.seudominio.com.br
POSTGRES_PASSWORD=senha
POSTGRES_USER=postgres           # Opcional, padrão: postgres
POSTGRES_DB=esus                 # Opcional, padrão: esus
```

### Banco Externo (Opção 2 - Atual):
```env
DOMAIN=esus.seudominio.com.br
APP_DB_URL=jdbc:postgresql://host:5432/database
APP_DB_USER=postgres
APP_DB_PASSWORD=senha
```

### Outras (Opcionais):
```env
URL_DOWNLOAD_ESUS=https://arquivos.esusab.ufsc.br/PEC/.../eSUS-AB-PEC-x.x.xx-Linux64.jar
```

---

## 🌐 Configuração de Domínio

O Traefik está configurado para gerar SSL automático via Let's Encrypt.

**No Coolify:**
1. Configure a variável `DOMAIN`
2. Ou adicione o domínio na interface do Coolify

**Resultado:**
- Acesso: `https://esus.seudominio.com.br`
- SSL automático
- Sem necessidade de porta na URL

---

## 📊 Status da Aplicação

### Primeira execução (~5-10 minutos):
- Download do eSUS (~800MB)
- Instalação e configuração
- Criação do schema do banco
- Migrações Liquibase

### Reinicializações (~1-2 minutos):
- Apenas startup do servidor

### Verificar logs:
No Coolify → Recurso → Logs

Procure por:
```
✅ Conexão com banco de dados OK!
=== Instalação concluída! ===
=== Iniciando servidor eSUS ===
```

---

## 🔧 Troubleshooting

### "Connection refused" ao banco

**Causa:** Banco não acessível

**Solução Banco Local:**
- Descomente o serviço `database` no docker-compose.yaml (linhas 8-23)
- Descomente `depends_on` no webserver (linhas 49-51)
- Descomente `volumes: postgres_data` (linhas 62-64)

**Solução Banco Externo:**
- Certifique-se que o banco está linkado no Coolify
- Verifique se o host está correto
- Confirme que ambos estão no mesmo servidor

### "Authentication failed"

**Causa:** Senha incorreta

**Solução:**
- Verifique `APP_DB_PASSWORD` corresponde à senha do banco
- Se banco local: `POSTGRES_PASSWORD` deve ser igual

### Porta já alocada

**Causa:** Porta 8080 em uso

**Não é necessário configurar porta!** O Traefik faz o proxy automático via domínio.

---

## 📁 Estrutura do Projeto

```
.
├── docker-compose.yaml       # Compose principal (banco comentado)
├── database/                 # Dockerfile do PostgreSQL
├── webserver/                # Dockerfile do eSUS
│   ├── Dockerfile
│   └── startup.sh           # Script de inicialização
├── README.md                # Este arquivo
└── *.md                     # Documentações adicionais
```

---

## 🔄 Alternar entre Banco Local e Externo

### Para usar Banco Local:

1. **Descomente** no `docker-compose.yaml`:
   - Serviço `database` (linhas 8-23)
   - `depends_on` no webserver (linhas 49-51)
   - `volumes: postgres_data` (linhas 62-64)

2. **Configure**:
   ```env
   DOMAIN=esus.seudominio.com.br
   POSTGRES_PASSWORD=senha
   ```

3. **Redeploy**

### Para usar Banco Externo (Configuração atual):

1. **Mantenha comentado** (já está):
   - Serviço `database`
   - `depends_on`
   - `volumes: postgres_data`

2. **Configure**:
   ```env
   DOMAIN=esus.seudominio.com.br
   APP_DB_URL=jdbc:postgresql://host:5432/db
   APP_DB_USER=user
   APP_DB_PASSWORD=senha
   ```

3. **Linke o banco PostgreSQL no Coolify** (Storages & Databases)

4. **Redeploy**

---

## 📚 Documentação Adicional

- **COOLIFY-SETUP.md** - Guia detalhado de configuração (descontinuado - use este README)
- **TROUBLESHOOTING.md** - Resolução de problemas
- **CHANGELOG.md** - Histórico de mudanças
- **CONFIGURAR-DOMINIO.md** - Configuração de domínio
- **DEBUG-PASSWORD-ISSUES.md** - Debug de problemas de senha

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Abra issues ou PRs.

---

## 📝 Licença

Este projeto é fornecido "como está" para facilitar o deploy do eSUS PEC.

O eSUS PEC é um software do Ministério da Saúde do Brasil.

---

## 🆘 Suporte

- Issues: [GitHub Issues](https://github.com/obsinto/esus-coolify/issues)
- Documentação oficial do eSUS: https://aps.saude.gov.br/ape/esus

---

**Desenvolvido para facilitar o deploy do eSUS PEC no Coolify** 🚀
