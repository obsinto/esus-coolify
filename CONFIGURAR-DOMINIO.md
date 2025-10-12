# Configurar Domínio sem Porta no Coolify

## Método 1: Usando Proxy do Coolify (Recomendado)

### Passo a passo:

1. **No Coolify, vá no recurso do eSUS**

2. **Procure pela seção "Domains" ou "URLs"**
   - Pode estar em: Configuration → Domains
   - Ou diretamente na página principal do recurso

3. **Adicione um domínio:**
   ```
   esus.seudominio.com.br
   ```

   Ou use um subdomínio:
   ```
   app.seudominio.com.br
   saude.seudominio.com.br
   pec.seudominio.com.br
   ```

4. **Configure o port:**
   - Port: `8081` (ou a porta que você configurou em WEB_PORT)
   - Protocol: `http` (o Coolify converte para https)

5. **Salve**

### O que o Coolify faz automaticamente:

✅ Configura proxy reverso (Traefik)
✅ Gera certificado SSL via Let's Encrypt
✅ Redireciona HTTP → HTTPS
✅ Remove necessidade da porta na URL

### Resultado:

**Antes:**
```
http://seu-servidor:8081
```

**Depois:**
```
https://esus.seudominio.com.br
```

---

## Método 2: DNS Configuration

### Se você tem um domínio:

1. **Configure DNS (no seu provedor de DNS):**
   ```
   Type: A
   Name: esus (ou @ para root)
   Value: IP_DO_SEU_SERVIDOR
   TTL: 3600
   ```

2. **No Coolify, adicione o domínio** (como acima)

3. **Aguarde propagação DNS** (~5-60 minutos)

### Se NÃO tem domínio:

**Opção A: Usar domínio gratuito do Coolify**
- Alguns Coolify oferecem subdomínios automáticos
- Ex: `seu-app.coolify.app`

**Opção B: Usar serviços gratuitos**
- [Duck DNS](https://www.duckdns.org/) - Gratuito
- [No-IP](https://www.noip.com/) - Gratuito com limitações
- [Cloudflare](https://www.cloudflare.com/) - Domínio + proxy gratuito

---

## Método 3: Nginx Reverse Proxy Manual

Se o Coolify não tiver proxy integrado (raro), configure manualmente:

### 1. Instalar Nginx no servidor:

```bash
apt update && apt install nginx certbot python3-certbot-nginx -y
```

### 2. Criar configuração:

```bash
cat > /etc/nginx/sites-available/esus << 'EOF'
server {
    listen 80;
    server_name esus.seudominio.com.br;

    location / {
        proxy_pass http://localhost:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
```

### 3. Ativar e gerar SSL:

```bash
ln -s /etc/nginx/sites-available/esus /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
certbot --nginx -d esus.seudominio.com.br
```

---

## Verificar se funcionou:

### 1. Testar localmente (no servidor):

```bash
curl -I http://localhost:8081
```

Deve retornar `HTTP/1.1 200 OK`

### 2. Testar pelo domínio:

```bash
curl -I https://esus.seudominio.com.br
```

### 3. Abrir no navegador:

```
https://esus.seudominio.com.br
```

---

## Troubleshooting

### Erro: "502 Bad Gateway"

**Causa:** Container não está rodando ou porta incorreta

**Solução:**
```bash
docker ps | grep webserver
# Verificar se está na porta 8081
```

### Erro: "SSL Certificate Error"

**Causa:** Certificado ainda não gerado

**Solução:**
- Aguarde alguns minutos
- Certifique-se que o DNS está apontando corretamente
- No Coolify, force regeneração do certificado

### Erro: "This site can't be reached"

**Causa:** DNS não configurado ou propagação pendente

**Solução:**
```bash
# Testar DNS
nslookup esus.seudominio.com.br
dig esus.seudominio.com.br

# Deve retornar o IP do seu servidor
```

---

## Exemplo completo de configuração:

### No seu provedor de DNS:
```
Type: A
Name: esus
Value: 203.0.113.10 (seu IP)
```

### No Coolify:
```
Domain: esus.seudominio.com.br
Port: 8081
Protocol: http
SSL: Auto (Let's Encrypt)
```

### Resultado:
```
✅ https://esus.seudominio.com.br
```

Sem porta, com SSL, tudo automático! 🚀
