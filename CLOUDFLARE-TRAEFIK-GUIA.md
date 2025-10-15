# Guia Técnico: Cloudflare Proxy + Coolify/Traefik

> **Objetivo:** Entender como o Cloudflare Proxy interage com Traefik/Coolify, incluindo SSL/TLS em cascata, headers de IP real e configurações avançadas.
>
> **Fontes:** Documentação Coolify, Cloudflare Docs, Traefik Community

---

## Índice

- [1. Arquitetura: Cloudflare + Traefik (Proxy em Cascata)](#1-arquitetura-cloudflare--traefik-proxy-em-cascata)
- [2. Modos SSL/TLS do Cloudflare](#2-modos-ssltls-do-cloudflare)
- [3. Certificados: Let's Encrypt vs Cloudflare Origin](#3-certificados-lets-encrypt-vs-cloudflare-origin)
- [4. Real IP: Como obter o IP original do cliente](#4-real-ip-como-obter-o-ip-original-do-cliente)
- [5. Configuração Passo a Passo](#5-configuração-passo-a-passo)
- [6. Troubleshooting](#6-troubleshooting)
- [7. Comparação: Com vs Sem Cloudflare Proxy](#7-comparação-com-vs-sem-cloudflare-proxy)

---

## 1. Arquitetura: Cloudflare + Traefik (Proxy em Cascata)

### 1.1 O que acontece quando você ativa o Cloudflare Proxy

**SEM Cloudflare Proxy (DNS Only):**

```
Cliente (navegador)
    ↓
    | [HTTPS Request]
    | Host: app.exemplo.com
    ↓
DNS resolve: app.exemplo.com → IP_DO_SERVIDOR (200.100.50.25)
    ↓
Requisição direta para IP_DO_SERVIDOR:443
    ↓
Traefik (no servidor)
    ↓
    | [Traefik descriptografa SSL]
    | [Verifica rotas]
    ↓
Container da aplicação
```

**Fluxo simples:**
- Cliente conecta **diretamente** ao seu servidor
- Traefik gerencia SSL (Let's Encrypt)
- IP do cliente visível para Traefik

---

**COM Cloudflare Proxy (Proxied):**

```
Cliente (navegador)
    ↓
    | [HTTPS Request]
    | Host: app.exemplo.com
    ↓
DNS resolve: app.exemplo.com → IP_CLOUDFLARE (104.26.x.x)
    ↓
Requisição vai para Cloudflare
    ↓
╔════════════════════════════════════════════════════════╗
║              CLOUDFLARE (Proxy Layer)                  ║
║  - Descriptografa SSL (certificado Cloudflare)        ║
║  - Aplica regras de firewall (WAF)                    ║
║  - Cache de conteúdo estático                         ║
║  - DDoS protection                                    ║
║  - Bot detection                                       ║
║  - Rate limiting                                       ║
╚════════════════════════════════════════════════════════╝
    ↓
    | [Nova conexão HTTPS/HTTP]
    | IP de origem: IP_CLOUDFLARE (não do cliente!)
    ↓
Traefik (no servidor)
    ↓
    | [Traefik descriptografa SSL novamente]
    | [Verifica rotas]
    ↓
Container da aplicação
```

**Fluxo com proxy em cascata:**
- Cliente conecta ao **Cloudflare** (não ao seu servidor)
- Cloudflare descriptografa, processa e **re-encripta**
- Cloudflare conecta ao seu servidor (segunda conexão SSL/TLS)
- Traefik vê o IP do Cloudflare, não do cliente

### 1.2 Por que usar Cloudflare Proxy?

**Vantagens:**

1. **DDoS Protection:**
   - Cloudflare absorve ataques (até petabits/segundo)
   - Seu servidor nunca vê tráfego malicioso

2. **WAF (Web Application Firewall):**
   - Bloqueia SQL injection, XSS, etc.
   - Regras gerenciadas atualizadas constantemente

3. **Cache global (CDN):**
   - Conteúdo estático servido de edge servers
   - Reduz latência (usuários próximos de POPs Cloudflare)

4. **Esconde IP real do servidor:**
   - Atacantes não sabem onde atacar
   - Protege contra ataques diretos

5. **Rate limiting e bot management:**
   - Bloqueia bots maliciosos
   - Rate limit por IP/país/ASN

**Desvantagens:**

1. **Latência adicional:**
   - Requisição passa por proxy extra
   - ~20-50ms adicional (geralmente imperceptível)

2. **Ponto único de falha:**
   - Se Cloudflare cai, seu site cai
   - Histórico: incidentes raros mas impactantes

3. **Complexidade SSL/TLS:**
   - Dois terminais SSL (Cloudflare → Servidor)
   - Certificados precisam estar sincronizados

4. **IP real do cliente mascarado:**
   - Aplicação vê IP do Cloudflare
   - Precisa ler headers especiais (`CF-Connecting-IP`)

5. **Dependência de terceiros:**
   - Cloudflare pode bloquear/suspender conta
   - ToS pode mudar

---

## 2. Modos SSL/TLS do Cloudflare

**Fonte:** https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/

Cloudflare oferece 4 modos de SSL/TLS (configuração: Dashboard → SSL/TLS → Overview)

### 2.1 Off (Não recomendado)

```
Cliente → [HTTPS] → Cloudflare → [HTTP] → Servidor
```

**Como funciona:**
- Cliente conecta via HTTPS no Cloudflare
- Cloudflare conecta via **HTTP puro** no servidor
- Traefik recebe tráfego não criptografado

**Problemas:**
- ❌ Tráfego entre Cloudflare e servidor é **plain text**
- ❌ Qualquer pessoa na rede pode interceptar (ISP, backbone)
- ❌ Violação de compliance (GDPR, PCI-DSS)
- ❌ Certificados do seu servidor são ignorados

**Quando usar:**
- Nunca em produção
- Apenas para debug local

---

### 2.2 Flexible (Não recomendado)

```
Cliente → [HTTPS] → Cloudflare → [HTTP] → Servidor
```

**Como funciona:**
- Idêntico ao modo "Off"
- Cliente vê cadeado verde (HTTPS válido)
- Servidor recebe HTTP puro

**Problemas:**
- ❌ Mesmos problemas do modo "Off"
- ❌ Falsa sensação de segurança (cliente pensa que é seguro)
- ❌ Man-in-the-middle possível entre Cloudflare e servidor

**Quando usar:**
- Servidores legados sem suporte HTTPS
- Migração temporária (deve ser temporário!)

---

### 2.3 Full (⚠️ Usar com cautela)

```
Cliente → [HTTPS] → Cloudflare → [HTTPS] → Servidor
```

**Como funciona:**
- Cliente conecta via HTTPS no Cloudflare (certificado Cloudflare)
- Cloudflare conecta via HTTPS no servidor (certificado do servidor)
- Traefik apresenta certificado SSL (Let's Encrypt ou self-signed)
- Cloudflare **NÃO valida** o certificado do servidor

**Vantagens:**
- ✅ Tráfego criptografado em ambos os lados
- ✅ Funciona com certificados self-signed
- ✅ Funciona com certificados expirados (!!)

**Problemas:**
- ⚠️ Cloudflare não valida identidade do servidor
- ⚠️ Vulnerável a man-in-the-middle (teoricamente)
- ⚠️ Atacante pode substituir seu servidor (se souber o IP)

**Quando usar:**
- Ambiente de desenvolvimento
- Servidores internos com self-signed certs
- Transição para Full (Strict)

---

### 2.4 Full (Strict) ✅ (Recomendado para produção)

```
Cliente → [HTTPS] → Cloudflare → [HTTPS (validado)] → Servidor
```

**Como funciona:**
- Cliente conecta via HTTPS no Cloudflare
- Cloudflare conecta via HTTPS no servidor
- Traefik apresenta certificado **válido e confiável**
- Cloudflare **valida** o certificado:
  - ✅ Domínio corresponde ao certificado
  - ✅ Certificado não expirou
  - ✅ Emitido por CA confiável (Let's Encrypt, Cloudflare Origin CA)

**Vantagens:**
- ✅ Máxima segurança (end-to-end encryption)
- ✅ Validação de identidade do servidor
- ✅ Protege contra man-in-the-middle
- ✅ Compliance (GDPR, PCI-DSS, HIPAA)

**Requisitos:**
- Certificado válido no servidor:
  - Let's Encrypt (automático via Traefik) OU
  - Cloudflare Origin Certificate (15 anos de validade)

**Quando usar:**
- **Sempre em produção**
- Quando segurança é crítica

---

## 3. Certificados: Let's Encrypt vs Cloudflare Origin

### 3.1 Opção 1: Let's Encrypt (via Traefik) com Cloudflare Proxy

**Problema comum: Desafio HTTP-01 falha**

```
Traefik solicita certificado Let's Encrypt:
  ↓
Let's Encrypt tenta validar: http://app.exemplo.com/.well-known/acme-challenge/TOKEN
  ↓
Requisição vai para Cloudflare (proxy ativado)
  ↓
Cloudflare encaminha para Traefik
  ↓
❌ PROBLEMA: Cloudflare pode bloquear/modificar requisição
  ↓
Let's Encrypt: "Validação falhou!"
```

**Soluções:**

#### **Solução A: Desativar proxy temporariamente**

```
1. Cloudflare Dashboard → DNS
2. Encontrar registro: app.exemplo.com
3. Mudar de "Proxied" (nuvem laranja) para "DNS Only" (nuvem cinza)
4. Aguardar propagação DNS (~5 minutos)
5. Traefik solicita certificado Let's Encrypt
6. Certificado obtido com sucesso ✅
7. Reativar proxy: "DNS Only" → "Proxied"
```

**Vantagens:**
- ✅ Simples
- ✅ Certificados Let's Encrypt gratuitos
- ✅ Renovação automática pelo Traefik

**Desvantagens:**
- ⚠️ Precisa desativar proxy a cada renovação? **NÃO!**
  - Depois da primeira emissão, renovações funcionam normalmente
  - Cloudflare não interfere com `.well-known/acme-challenge/`

---

#### **Solução B: Usar desafio DNS-01 (wildcard)**

**Fonte:** https://coolify.io/docs/knowledge-base/proxy/traefik/wildcard-certs

```yaml
# Traefik configurado para DNS-01:
certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@exemplo.com
      storage: /letsencrypt/acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
```

**Variáveis de ambiente necessárias:**
```bash
CF_API_EMAIL=admin@exemplo.com
CF_DNS_API_TOKEN=seu_token_cloudflare
```

**Como funciona:**
```
Traefik solicita certificado wildcard (*.exemplo.com):
  ↓
Let's Encrypt solicita: "Crie registro TXT: _acme-challenge.exemplo.com"
  ↓
Traefik usa API Cloudflare para criar registro DNS
  ↓
Let's Encrypt valida registro DNS
  ↓
Certificado emitido ✅
  ↓
Traefik remove registro TXT
```

**Vantagens:**
- ✅ Funciona com Cloudflare Proxy ativado
- ✅ Suporta wildcard certificates (`*.exemplo.com`)
- ✅ Não precisa expor porta 80

**Desvantagens:**
- ⚠️ Requer API token Cloudflare
- ⚠️ Configuração mais complexa

---

### 3.2 Opção 2: Cloudflare Origin Certificate ✅ (Recomendado)

**Fonte:** https://coolify.io/docs/knowledge-base/cloudflare/origin-cert

**O que é:**
- Certificado emitido **pela Cloudflare**
- Válido por **15 anos**
- **Apenas confiável pela Cloudflare** (não por navegadores)
- Usado para criptografar tráfego Cloudflare → Servidor

**Por que usar:**
- ✅ Válido por 15 anos (sem renovação)
- ✅ Não precisa de desafios HTTP/DNS
- ✅ Pode fechar porta 80 (apenas HTTPS)
- ✅ Suporta wildcard (`*.exemplo.com`)
- ✅ Funciona perfeitamente com proxy Cloudflare

**Limitações:**
- ❌ Não funciona sem Cloudflare Proxy
- ❌ Wildcard no plano free: apenas 1 nível (`*.exemplo.com`, não `*.api.exemplo.com`)
- ❌ Se Cloudflare cai, site fica inacessível

---

#### **Como gerar e configurar:**

**Passo 1: Gerar certificado no Cloudflare**

```
1. Cloudflare Dashboard → SSL/TLS → Origin Server
2. Clicar em "Create Certificate"
3. Configurar:
   - Private key type: RSA (2048)
   - Hostnames:
     - exemplo.com
     - *.exemplo.com
   - Certificate validity: 15 years
4. Clicar em "Create"
5. Copiar:
   - Origin Certificate (PEM)
   - Private Key
```

**Passo 2: Adicionar certificado ao servidor**

```bash
# SSH no servidor Coolify:
ssh root@seu-servidor.com

# Criar diretório para certificados:
sudo mkdir -p /data/coolify/proxy/certs

# Criar arquivo do certificado:
sudo nano /data/coolify/proxy/certs/origem.pem
# Colar o "Origin Certificate"
# Salvar (Ctrl+O, Enter, Ctrl+X)

# Criar arquivo da chave privada:
sudo nano /data/coolify/proxy/certs/origem-key.pem
# Colar o "Private Key"
# Salvar

# Permissões:
sudo chmod 600 /data/coolify/proxy/certs/*
```

**Passo 3: Configurar Traefik para usar o certificado**

```yaml
# /data/coolify/proxy/dynamic/cloudflare-origin.yaml
tls:
  certificates:
    - certFile: /certs/origem.pem
      keyFile: /certs/origem-key.pem
      stores:
        - default
  stores:
    default:
      defaultCertificate:
        certFile: /certs/origem.pem
        keyFile: /certs/origem-key.pem
```

**Passo 4: Reiniciar Traefik**

```bash
docker restart coolify-proxy
```

**Passo 5: Configurar Cloudflare**

```
1. DNS: Certificar que está "Proxied" (nuvem laranja)
2. SSL/TLS → Overview: Mudar para "Full (Strict)"
3. SSL/TLS → Edge Certificates:
   - ✅ Always Use HTTPS: On
   - ✅ Automatic HTTPS Rewrites: On
```

---

### 3.3 Comparação: Let's Encrypt vs Cloudflare Origin

| Aspecto | Let's Encrypt | Cloudflare Origin |
|---------|---------------|-------------------|
| **Validade** | 90 dias | 15 anos |
| **Renovação** | Automática (Traefik) | Manual (a cada 15 anos) |
| **Funciona sem Cloudflare** | ✅ Sim | ❌ Não |
| **Wildcard** | ✅ Sim (DNS-01) | ✅ Sim (free: 1 nível) |
| **Configuração** | Automática | Manual |
| **Confiabilidade** | Navegadores confiam | Apenas Cloudflare confia |
| **Porta 80** | Precisa aberta (HTTP-01) | Pode fechar |
| **Melhor para** | Flexibilidade, multi-cloud | Cloudflare exclusivo |

**Recomendação:**

- **Se usa Cloudflare Proxy sempre:** Cloudflare Origin Certificate
- **Se pode precisar remover Cloudflare:** Let's Encrypt (DNS-01)
- **Máxima flexibilidade:** Let's Encrypt (HTTP-01) + desativar proxy na primeira emissão

---

## 4. Real IP: Como obter o IP original do cliente

### 4.1 O problema

```
SEM Cloudflare:
Cliente (IP: 203.0.113.45) → Traefik → Aplicação
Aplicação vê: 203.0.113.45 ✅

COM Cloudflare:
Cliente (IP: 203.0.113.45) → Cloudflare (IP: 104.26.x.x) → Traefik → Aplicação
Aplicação vê: 104.26.x.x ❌ (IP do Cloudflare, não do cliente!)
```

**Por que isso é um problema?**

1. **Rate limiting quebra:**
   - Todos os usuários parecem ter o mesmo IP (Cloudflare)
   - Rate limit bloqueia todos ou ninguém

2. **Geolocalização falha:**
   - IP do Cloudflare é nos EUA (geralmente)
   - Aplicação pensa que todos os usuários são dos EUA

3. **Logs inúteis:**
   - Logs mostram IP do Cloudflare
   - Impossível rastrear usuários específicos

4. **Bloqueio de IP não funciona:**
   - Bloquear IP malicioso não funciona (bloqueia Cloudflare)
   - Atacante continua acessando

### 4.2 Como o Cloudflare envia o IP real

**Cloudflare adiciona headers HTTP:**

```http
GET /api/users HTTP/1.1
Host: app.exemplo.com
X-Forwarded-For: 203.0.113.45, 172.68.1.1
X-Real-IP: 203.0.113.45
CF-Connecting-IP: 203.0.113.45
CF-IPCountry: BR
CF-Visitor: {"scheme":"https"}
True-Client-IP: 203.0.113.45  (Enterprise apenas)
```

**Headers importantes:**

| Header | Valor | Confiabilidade |
|--------|-------|----------------|
| `CF-Connecting-IP` | IP real do cliente | ✅ Sempre confiável (Cloudflare garante) |
| `X-Forwarded-For` | Lista de IPs (cliente, proxies) | ⚠️ Pode ser falsificado |
| `X-Real-IP` | IP do último proxy | ⚠️ Pode ser falsificado |
| `True-Client-IP` | IP real (Enterprise) | ✅ Confiável |

**Por que `X-Forwarded-For` não é confiável?**

```http
# Cliente malicioso pode enviar:
GET / HTTP/1.1
X-Forwarded-For: 1.1.1.1, 8.8.8.8

# Cloudflare adiciona o IP real:
X-Forwarded-For: 1.1.1.1, 8.8.8.8, 203.0.113.45
                  ^^^^^^^^^^^^^  ^^^^^^^^^^^^^^
                  FALSIFICADO    IP REAL

# Aplicação vê: [1.1.1.1, 8.8.8.8, 203.0.113.45]
# Qual é o verdadeiro? 🤔
```

**Solução:** Usar `CF-Connecting-IP` (Cloudflare garante autenticidade)

### 4.3 Configurar Traefik para confiar no Cloudflare

**Problema:** Traefik não confia em headers por padrão (segurança)

**Solução:** Adicionar IPs do Cloudflare como "trusted proxies"

**Fonte:** https://plugins.traefik.io/plugins/62e97498e2bf06d4675b9443/real-ip-from-cloudflare-proxy-tunnel

#### **Opção 1: Configuração manual (não recomendado)**

```yaml
# /data/coolify/proxy/traefik.yaml
entryPoints:
  web:
    address: ":80"
    forwardedHeaders:
      trustedIPs:
        - "173.245.48.0/20"
        - "103.21.244.0/22"
        - "103.22.200.0/22"
        - "103.31.4.0/22"
        - "141.101.64.0/18"
        - "108.162.192.0/18"
        - "190.93.240.0/20"
        - "188.114.96.0/20"
        - "197.234.240.0/22"
        - "198.41.128.0/17"
        - "162.158.0.0/15"
        - "104.16.0.0/13"
        - "104.24.0.0/14"
        - "172.64.0.0/13"
        - "131.0.72.0/22"
```

**Problema:**
- ⚠️ Cloudflare muda IPs periodicamente
- ⚠️ Precisa atualizar manualmente
- ⚠️ Lista extensa (difícil de manter)

---

#### **Opção 2: Plugin Traefik (recomendado)**

**Plugin:** https://plugins.traefik.io/plugins/62e97498e2bf06d4675b9443/real-ip-from-cloudflare-proxy-tunnel

**O que faz:**
- ✅ Atualiza IPs do Cloudflare automaticamente
- ✅ Substitui `X-Real-IP` com `CF-Connecting-IP`
- ✅ Valida que requisição veio do Cloudflare

**Instalação:**

```yaml
# /data/coolify/proxy/traefik.yaml
experimental:
  plugins:
    cloudflarewarp:
      moduleName: "github.com/BetterCorp/cloudflarewarp"
      version: "v1.3.3"
```

**Configuração por serviço:**

```yaml
# Labels no docker-compose.yml (Coolify adiciona automaticamente):
labels:
  - "traefik.http.middlewares.cf-real-ip.plugin.cloudflarewarp.disableDefault=false"
  - "traefik.http.routers.meu-app.middlewares=cf-real-ip"
```

**Ou configuração global:**

```yaml
# /data/coolify/proxy/dynamic/cloudflare-middleware.yaml
http:
  middlewares:
    cf-real-ip:
      plugin:
        cloudflarewarp:
          disableDefault: false
          trustip:
            - "173.245.48.0/20"
            # ... outros IPs (plugin atualiza automaticamente)
```

**Aplicar em todas as rotas:**

```yaml
# Coolify UI → Server → Proxy → Add Middleware
http:
  routers:
    default:
      middlewares:
        - cf-real-ip
```

---

### 4.4 Verificar se está funcionando

**Teste:**

```bash
# Fazer requisição através do Cloudflare:
curl -H "Host: app.exemplo.com" https://app.exemplo.com/api/test

# Ver logs do Traefik:
docker logs coolify-proxy --tail 50

# Procurar por:
# X-Real-IP: 203.0.113.45  (IP real do cliente, não do Cloudflare)
```

**Teste na aplicação:**

```javascript
// Node.js (Express)
app.get('/api/ip', (req, res) => {
  res.json({
    'X-Real-IP': req.headers['x-real-ip'],
    'CF-Connecting-IP': req.headers['cf-connecting-ip'],
    'X-Forwarded-For': req.headers['x-forwarded-for'],
    'Remote Address': req.connection.remoteAddress
  });
});

// Resposta esperada:
{
  "X-Real-IP": "203.0.113.45",  // ✅ IP real
  "CF-Connecting-IP": "203.0.113.45",  // ✅ IP real
  "X-Forwarded-For": "203.0.113.45, 104.26.x.x",
  "Remote Address": "172.18.0.5"  // IP interno Docker
}
```

---

## 5. Configuração Passo a Passo

### Cenário: eSUS-Docker com Cloudflare Proxy

**Objetivo:**
- ✅ Cloudflare Proxy ativado (DDoS protection, WAF)
- ✅ SSL Full (Strict) com Cloudflare Origin Certificate
- ✅ IP real do cliente disponível na aplicação

---

### **Passo 1: Gerar Cloudflare Origin Certificate**

```
1. Login no Cloudflare
2. Selecionar domínio: exemplo.com
3. Ir para: SSL/TLS → Origin Server
4. Clicar: "Create Certificate"
5. Configurar:
   - Private key type: RSA (2048)
   - Hostnames:
     - esus.exemplo.com
     - *.esus.exemplo.com  (se usar subdomínios)
   - Validity: 15 years
6. Criar e copiar:
   - Origin Certificate
   - Private Key
```

---

### **Passo 2: Adicionar certificado ao servidor Coolify**

```bash
# SSH no servidor:
ssh root@servidor-coolify.com

# Criar diretório:
sudo mkdir -p /data/coolify/proxy/certs

# Certificado:
sudo nano /data/coolify/proxy/certs/esus-origem.pem
# Colar "Origin Certificate"
# Salvar e fechar

# Chave privada:
sudo nano /data/coolify/proxy/certs/esus-origem-key.pem
# Colar "Private Key"
# Salvar e fechar

# Permissões:
sudo chmod 600 /data/coolify/proxy/certs/*
sudo chown root:root /data/coolify/proxy/certs/*
```

---

### **Passo 3: Configurar Traefik para usar o certificado**

```bash
# Criar configuração dinâmica:
sudo nano /data/coolify/proxy/dynamic/esus-cloudflare.yaml
```

```yaml
# Conteúdo:
tls:
  certificates:
    - certFile: /certs/esus-origem.pem
      keyFile: /certs/esus-origem-key.pem
      stores:
        - default

  stores:
    default:
      defaultCertificate:
        certFile: /certs/esus-origem.pem
        keyFile: /certs/esus-origem-key.pem

http:
  middlewares:
    cloudflare-real-ip:
      plugin:
        cloudflarewarp:
          disableDefault: false
```

```bash
# Salvar e fechar

# Reiniciar Traefik:
docker restart coolify-proxy

# Verificar logs:
docker logs coolify-proxy --tail 50
# Deve mostrar: "Configuration loaded from file: /dynamic/esus-cloudflare.yaml"
```

---

### **Passo 4: Configurar DNS no Cloudflare**

```
1. Cloudflare Dashboard → DNS → Records
2. Adicionar/editar registro:
   - Type: A
   - Name: esus
   - IPv4 address: IP_DO_SERVIDOR
   - Proxy status: ✅ Proxied (nuvem laranja)
   - TTL: Auto
3. Salvar
```

---

### **Passo 5: Configurar SSL/TLS no Cloudflare**

```
1. SSL/TLS → Overview:
   - Encryption mode: Full (Strict) ✅

2. SSL/TLS → Edge Certificates:
   - ✅ Always Use HTTPS: On
   - ✅ Automatic HTTPS Rewrites: On
   - ✅ Minimum TLS Version: 1.2
   - ⚠️ TLS 1.3: On (opcional, recomendado)

3. Security → Settings:
   - Security Level: Medium (ou High para mais proteção)
   - ✅ Bot Fight Mode: On
   - ✅ Challenge Passage: 30 minutes
```

---

### **Passo 6: Configurar aplicação no Coolify**

```
1. Coolify UI → Seu projeto → webserver
2. Domain:
   - URL: https://esus.exemplo.com
   - (Coolify detecta automaticamente que deve usar HTTPS)
3. Variáveis de ambiente (se necessário):
   - TRUSTED_PROXIES=173.245.48.0/20,103.21.244.0/22,...
   - (ou usar plugin Traefik)
4. Deploy
```

---

### **Passo 7: Testar**

```bash
# Teste 1: SSL
curl -I https://esus.exemplo.com
# Deve retornar: HTTP/2 200
# Certificate: válido (Cloudflare)

# Teste 2: IP real
curl https://esus.exemplo.com/api/test
# Verificar se aplicação recebe IP real (não do Cloudflare)

# Teste 3: Verificar certificado do servidor
openssl s_client -connect esus.exemplo.com:443 -servername esus.exemplo.com
# Issuer: Cloudflare Inc ECC CA-3
# (certificado apresentado pelo Cloudflare aos clientes)

# Teste 4: Verificar certificado no servidor (direto)
openssl s_client -connect IP_DO_SERVIDOR:443 -servername esus.exemplo.com
# Issuer: Cloudflare Origin CA
# (certificado entre Cloudflare e seu servidor)
```

---

## 6. Troubleshooting

### Problema 1: "SSL Handshake Failed" ou "526 Invalid SSL Certificate"

**Erro no navegador:**
```
Error 526: Invalid SSL certificate
```

**Causa:**
- Cloudflare configurado como "Full (Strict)"
- Servidor não tem certificado válido (ou expirado)

**Diagnóstico:**

```bash
# Verificar certificado do servidor:
echo | openssl s_client -connect IP_DO_SERVIDOR:443 -servername esus.exemplo.com 2>/dev/null | openssl x509 -noout -dates

# Verificar se Traefik está usando o certificado correto:
docker exec coolify-proxy cat /certs/esus-origem.pem
# Deve mostrar o certificado
```

**Solução:**

1. Verificar que certificado foi adicionado corretamente em `/data/coolify/proxy/certs/`
2. Verificar configuração Traefik em `/data/coolify/proxy/dynamic/`
3. Reiniciar Traefik: `docker restart coolify-proxy`
4. Se usar Let's Encrypt: desativar proxy temporariamente

---

### Problema 2: "Too Many Redirects" (Loop infinito)

**Erro no navegador:**
```
ERR_TOO_MANY_REDIRECTS
```

**Causa:**
- Cloudflare envia HTTPS para o servidor
- Servidor força redirect HTTP → HTTPS
- Cloudflare recebe redirect e envia HTTPS novamente (loop)

**Fluxo do problema:**

```
1. Cliente → Cloudflare (HTTPS)
2. Cloudflare → Servidor (HTTP - modo Flexible)
3. Servidor: "Redirect para HTTPS" → Cloudflare
4. Cloudflare → Servidor (HTTP novamente)
5. Loop infinito ♾️
```

**Solução:**

1. **Mudar modo SSL no Cloudflare:**
   - SSL/TLS → Overview → Full ou Full (Strict)

2. **Ou desativar force HTTPS no servidor:**
   ```yaml
   # Remover middleware redirect-to-https
   labels:
     - "traefik.http.middlewares.redirect-https.redirectscheme.scheme=https"
   ```

3. **Ou usar Cloudflare para fazer redirect:**
   - Page Rules → "Always Use HTTPS"
   - Servidor não precisa fazer redirect

---

### Problema 3: Aplicação vê apenas IPs do Cloudflare

**Sintoma:**
- Logs mostram IPs `104.26.x.x`, `172.64.x.x` (IPs Cloudflare)
- Rate limiting não funciona (todos parecem ser o mesmo usuário)

**Diagnóstico:**

```bash
# Ver headers recebidos:
docker exec -it esus-docker-webserver-1 bash
# Dentro do container:
env | grep -i forward

# Ou testar endpoint:
curl https://esus.exemplo.com/debug/headers
```

**Solução:**

1. **Instalar plugin Cloudflare no Traefik** (ver seção 4.3)

2. **Ou configurar `trustedIPs` manualmente:**

```yaml
# /data/coolify/proxy/traefik.yaml
entryPoints:
  websecure:
    address: ":443"
    forwardedHeaders:
      trustedIPs:
        - "173.245.48.0/20"
        - "103.21.244.0/22"
        # ... (lista completa em: https://www.cloudflare.com/ips/)
```

3. **Ou ler `CF-Connecting-IP` na aplicação:**

```javascript
// Express.js
app.set('trust proxy', true);

app.use((req, res, next) => {
  req.realIP = req.headers['cf-connecting-ip'] || req.ip;
  next();
});
```

---

### Problema 4: Let's Encrypt falha ao renovar certificado

**Erro nos logs do Traefik:**
```
Unable to obtain ACME certificate for domains "esus.exemplo.com"
acme: error: 403 :: urn:ietf:params:acme:error:unauthorized
```

**Causa:**
- Cloudflare Proxy bloqueia desafio Let's Encrypt
- Firewall Cloudflare bloqueando User-Agent do Let's Encrypt

**Solução:**

**Opção 1: Usar Cloudflare Origin Certificate** (recomendado)
- Não depende de Let's Encrypt
- Válido por 15 anos

**Opção 2: Desafio DNS-01**
- Funciona com proxy ativado
- Requer API token Cloudflare

**Opção 3: Whitelist User-Agent do Let's Encrypt**
```
Cloudflare → Security → WAF → Custom Rules:
  - Rule name: Allow Let's Encrypt
  - Expression:
    (http.user_agent contains "certbot") or
    (http.user_agent contains "Let's Encrypt")
  - Action: Allow
```

---

### Problema 5: Slow First Byte (TTFB alto)

**Sintoma:**
- Primeira requisição demora muito (2-5 segundos)
- Requisições seguintes são rápidas

**Causa:**
- Cloudflare fazendo validação SSL no primeiro acesso
- Cold start do Cloudflare Workers
- Origin não warm

**Diagnóstico:**

```bash
# Testar TTFB:
curl -w "@curl-format.txt" -o /dev/null -s https://esus.exemplo.com

# curl-format.txt:
time_namelookup:  %{time_namelookup}\n
time_connect:  %{time_connect}\n
time_appconnect:  %{time_appconnect}\n
time_pretransfer:  %{time_pretransfer}\n
time_redirect:  %{time_redirect}\n
time_starttransfer:  %{time_starttransfer}\n
----------\n
time_total:  %{time_total}\n
```

**Solução:**

1. **Habilitar cache Cloudflare:**
   ```
   Page Rules:
   - URL: esus.exemplo.com/*
   - Cache Level: Standard
   - Edge Cache TTL: 2 hours
   ```

2. **Habilitar HTTP/3 (QUIC):**
   ```
   Network → HTTP/3: On
   ```

3. **Argo Smart Routing** (pago):
   - Otimiza roteamento entre Cloudflare e servidor
   - ~$5/mês + $0.10/GB

4. **Warm up automatizado:**
   ```bash
   # Cron job para fazer requisição a cada 5 min:
   */5 * * * * curl -s https://esus.exemplo.com > /dev/null
   ```

---

## 7. Comparação: Com vs Sem Cloudflare Proxy

### 7.1 Arquitetura

| Aspecto | Sem Cloudflare Proxy | Com Cloudflare Proxy |
|---------|---------------------|----------------------|
| **Fluxo** | Cliente → Traefik → App | Cliente → CF → Traefik → App |
| **SSL Terminations** | 1 (Traefik) | 2 (CF + Traefik) |
| **IP visível** | IP real do cliente | IP Cloudflare |
| **Latência** | Baixa | +20-50ms |
| **Complexidade** | Simples | Média |

### 7.2 Segurança

| Recurso | Sem Cloudflare | Com Cloudflare |
|---------|----------------|----------------|
| **DDoS Protection** | ❌ Depende do provedor VPS | ✅ Até petabits/segundo |
| **WAF** | ❌ Não (ou manual) | ✅ Automático |
| **Rate Limiting** | ⚠️ Manual (Traefik) | ✅ Cloudflare + Traefik |
| **Bot Protection** | ❌ Não | ✅ Cloudflare Bot Manager |
| **IP do servidor oculto** | ❌ Exposto | ✅ Oculto |

### 7.3 Performance

| Métrica | Sem Cloudflare | Com Cloudflare |
|---------|----------------|----------------|
| **TTFB (primeira req)** | 50-200ms | 100-300ms |
| **TTFB (cache hit)** | 50-200ms | 10-50ms ✅ |
| **Latência global** | Alta (single region) | Baixa (edge servers) ✅ |
| **Bandwidth** | Pago (provedor VPS) | Ilimitado (plano free) ✅ |

### 7.4 Custos

| Item | Sem Cloudflare | Com Cloudflare |
|------|----------------|----------------|
| **Cloudflare** | $0 | $0 (free) ou $20-200/mês (Pro/Business) |
| **Certificados SSL** | $0 (Let's Encrypt) | $0 (CF Origin ou LE) |
| **Bandwidth** | Pago pelo VPS | Ilimitado (free) ✅ |
| **DDoS Protection** | Pago ($50-500/mês) | Incluído (free) ✅ |

### 7.5 Disponibilidade

| Cenário | Sem Cloudflare | Com Cloudflare |
|---------|----------------|----------------|
| **Servidor cai** | ❌ Site fora | ❌ Site fora (sem failover) |
| **Ataque DDoS** | ❌ Site fora | ✅ Site funciona |
| **Cloudflare cai** | ✅ Site funciona | ❌ Site fora |
| **Uptime histórico** | Depende do VPS | 99.99%+ (CF) |

### 7.6 Recomendação

**Use Cloudflare Proxy se:**
- ✅ Precisa de proteção DDoS/WAF
- ✅ Tem tráfego internacional (beneficia de CDN)
- ✅ Quer economia de bandwidth
- ✅ Não tem equipe de segurança dedicada

**NÃO use Cloudflare Proxy se:**
- ❌ Requisitos de compliance (dados não podem passar por terceiros)
- ❌ Aplicação precisa de WebSocket/gRPC (requer config extra)
- ❌ Latência crítica (trading, gaming)
- ❌ Quer controle total sobre infraestrutura

**Recomendação para eSUS-Docker:**
- ✅ **Use Cloudflare Proxy** (saúde pública, precisa de disponibilidade)
- ✅ **Modo Full (Strict)** com Cloudflare Origin Certificate
- ✅ **Configurar Real IP** (logs de acesso são importantes)

---

## Resumo Executivo

### O que acontece ao ativar Cloudflare Proxy:

1. **DNS aponta para Cloudflare** (não mais para seu servidor)
2. **Cloudflare se torna proxy reverso** (camada adicional)
3. **Dois terminais SSL/TLS:**
   - Cliente ↔ Cloudflare (certificado Cloudflare)
   - Cloudflare ↔ Servidor (certificado Let's Encrypt ou Origin)
4. **Traefik vê IP do Cloudflare** (precisa ler headers para IP real)
5. **Cloudflare adiciona segurança** (WAF, DDoS, bot protection)

### Configuração recomendada:

- ✅ **SSL/TLS:** Full (Strict)
- ✅ **Certificado:** Cloudflare Origin (15 anos)
- ✅ **Real IP:** Plugin Traefik ou `trustedIPs`
- ✅ **Cache:** Page Rules para estáticos
- ✅ **Segurança:** WAF + Bot Fight Mode

### Checklist de configuração:

- [ ] Gerar Cloudflare Origin Certificate
- [ ] Adicionar certificado em `/data/coolify/proxy/certs/`
- [ ] Configurar Traefik para usar o certificado
- [ ] DNS em modo "Proxied" (nuvem laranja)
- [ ] SSL/TLS: Full (Strict)
- [ ] Configurar Real IP (plugin ou `trustedIPs`)
- [ ] Testar SSL: `curl -I https://dominio.com`
- [ ] Testar Real IP: verificar logs da aplicação
- [ ] Habilitar "Always Use HTTPS"
- [ ] Configurar Page Rules (cache, redirect)

---

## Referências

- [Cloudflare SSL Modes](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/)
- [Coolify Cloudflare Origin Certificate](https://coolify.io/docs/knowledge-base/cloudflare/origin-cert)
- [Traefik Cloudflare Plugin](https://plugins.traefik.io/plugins/62e97498e2bf06d4675b9443/real-ip-from-cloudflare-proxy-tunnel)
- [Cloudflare IP Ranges](https://www.cloudflare.com/ips/)
- [Restoring Original Visitor IPs](https://developers.cloudflare.com/support/troubleshooting/restoring-visitor-ips/restoring-original-visitor-ips/)
