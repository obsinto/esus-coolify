# Guia Completo de Estudos: Coolify, Proxy Reverso e Docker

> **Objetivo:** Compreensão profunda da arquitetura, decisões de design e conceitos de infraestrutura do Coolify.
>
> **Fontes:** Documentação oficial do Coolify (https://coolify.io/docs), análise do projeto eSUS-Docker.

---

## Índice

- [A. Fundamentos de Proxy Reverso](#a-fundamentos-de-proxy-reverso)
- [B. Como o Coolify Funciona Internamente](#b-como-o-coolify-funciona-internamente)
- [C. Gerenciamento de Portas no Coolify](#c-gerenciamento-de-portas-no-coolify)
- [D. SSL Automático](#d-ssl-automático)
- [E. Análise do docker-compose.yml do eSUS-Docker](#e-análise-do-docker-composeyml-do-esus-docker)
- [F. Boas Práticas e Padrões](#f-boas-práticas-e-padrões)

---

## A. Fundamentos de Proxy Reverso

### A.1 O que é um Proxy Reverso?

Um **proxy reverso** é um servidor que fica posicionado **entre os clientes (navegadores, apps) e os servidores de aplicação**, funcionando como um intermediário que recebe requisições e as encaminha para os servidores corretos.

**Fluxo de requisição:**

```
Cliente (navegador)
    ↓
    | [HTTP/HTTPS Request]
    ↓
Proxy Reverso (Traefik/NGINX)
    ↓
    | [Decisão de roteamento baseada em:]
    | - Domínio (Host header)
    | - Path (/api, /admin)
    | - Porta
    ↓
Servidor de Aplicação (Container Docker)
    ↓
    | [Resposta]
    ↓
Proxy Reverso
    ↓
Cliente
```

### A.2 Por que aplicações web modernas precisam disso?

**1. Múltiplas aplicações em um único servidor:**
- Sem proxy reverso: cada app precisaria de um IP único ou porta diferente
- Com proxy reverso: `app1.exemplo.com`, `app2.exemplo.com` → mesmo servidor, portas 443/80

**2. Gerenciamento de SSL/TLS:**
- Centraliza certificados SSL em um único lugar
- Aplicações não precisam lidar com HTTPS (comunicação interna pode ser HTTP)
- Renovação automática de certificados

**3. Load Balancing:**
- Distribui requisições entre múltiplas instâncias de uma aplicação
- Aumenta disponibilidade e performance

**4. Segurança:**
- Esconde a estrutura interna da rede
- Pode adicionar autenticação, rate limiting, WAF
- Protege servidores de aplicação de acesso direto

**5. Flexibilidade:**
- Permite mudar servidores backend sem afetar clientes
- Facilita deployments blue-green e canary releases

### A.3 Diferença entre Proxy Tradicional (Forward) e Proxy Reverso

| Aspecto | Proxy Tradicional (Forward) | Proxy Reverso |
|---------|----------------------------|---------------|
| **Posição** | Do lado do cliente | Do lado do servidor |
| **Objetivo** | Proteger/anonimizar clientes | Proteger/otimizar servidores |
| **Quem configura** | Usuários/clientes | Administradores de sistema |
| **Exemplo de uso** | VPN corporativa, anonimização | Load balancing, SSL termination |
| **Conhecimento** | Cliente sabe que usa proxy | Cliente não sabe da existência |

**Exemplo prático:**

```
PROXY TRADICIONAL:
Funcionário → [Proxy Corporativo] → Internet
(empresa controla acesso à internet)

PROXY REVERSO:
Cliente → [Traefik/NGINX] → Aplicações internas
(servidores ficam ocultos)
```

### A.4 Como requisições HTTP/HTTPS são roteadas

**1. Cliente faz requisição:**
```http
GET / HTTP/1.1
Host: app.exemplo.com
```

**2. Proxy reverso analisa a requisição:**

```yaml
# Traefik identifica:
- Host header: app.exemplo.com
- Path: /
- Porta de destino: 80 (HTTP) ou 443 (HTTPS)
```

**3. Decisão de roteamento (baseada em regras):**

```
Se Host == "app.exemplo.com"
  → Encaminhar para container "webserver" na porta 8080

Se Host == "api.exemplo.com"
  → Encaminhar para container "api" na porta 3000

Se Host == "db.exemplo.com"
  → BLOQUEAR (banco de dados não deve ser exposto)
```

**4. Traefik encaminha para o container:**

```
http://webserver:8080/ (rede interna Docker)
```

**5. Resposta retorna pelo mesmo caminho:**

```
Container → Traefik → Cliente
```

### A.5 Conceitos importantes

**Host Header:**
- Identifica qual domínio foi requisitado
- Permite múltiplos sites no mesmo IP/porta
- Exemplo: `Host: meusite.com`

**SNI (Server Name Indication):**
- Extensão TLS que envia o hostname durante handshake SSL
- Permite múltiplos certificados SSL no mesmo IP
- Essencial para HTTPS com múltiplos domínios

**SSL Termination:**
- Proxy descriptografa HTTPS e encaminha HTTP internamente
- Reduz carga de processamento nos servidores de aplicação
- Simplifica gerenciamento de certificados

---

## B. Como o Coolify Funciona Internamente

### B.1 Arquitetura do Coolify

**Fonte:** Documentação oficial Coolify - https://coolify.io/docs

Coolify é uma **Platform as a Service (PaaS) auto-hospedada** que abstrai a complexidade de infraestrutura.

**Componentes principais:**

```
┌─────────────────────────────────────────────────────────┐
│                    COOLIFY STACK                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐  │
│  │           Coolify Application (Laravel)         │  │
│  │  - Interface Web                                │  │
│  │  - API REST                                     │  │
│  │  - Gerenciamento de deploy                     │  │
│  │  - Configuração de serviços                    │  │
│  └─────────────────────────────────────────────────┘  │
│                        ↓                                │
│  ┌─────────────────────────────────────────────────┐  │
│  │              Traefik (Proxy Reverso)            │  │
│  │  - Roteamento dinâmico                         │  │
│  │  - Gerenciamento SSL (Let's Encrypt)           │  │
│  │  - Load balancing                              │  │
│  │  - Middleware (auth, redirects)                │  │
│  └─────────────────────────────────────────────────┘  │
│                        ↓                                │
│  ┌─────────────────────────────────────────────────┐  │
│  │              Docker Engine                      │  │
│  │  - Containers de aplicação                     │  │
│  │  - Redes Docker                                │  │
│  │  - Volumes                                     │  │
│  └─────────────────────────────────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Fluxo de um deploy:**

```
1. [Git Push] → GitHub/GitLab
           ↓
2. [Webhook] → Coolify detecta mudança
           ↓
3. [Coolify] → Clona repositório
           ↓
4. [Coolify] → Analisa docker-compose.yml
           ↓
5. [Coolify] → Injeta labels Traefik nos serviços
           ↓
6. [Docker] → Build das imagens
           ↓
7. [Docker] → Cria rede isolada para o stack
           ↓
8. [Docker] → Inicia containers
           ↓
9. [Traefik] → Detecta novos containers (labels)
           ↓
10. [Traefik] → Configura rotas automaticamente
           ↓
11. [Traefik] → Solicita certificado SSL (se HTTPS)
           ↓
12. ✅ Aplicação disponível
```

### B.2 Como o Coolify gerencia o proxy reverso

**Tecnologia usada:** **Traefik v2/v3**

**Fonte:** https://coolify.io/docs/knowledge-base/proxy/traefik/overview

**Por que Traefik?**

1. **Integração nativa com Docker:**
   - Detecta containers automaticamente via Docker API
   - Não precisa recarregar configuração manualmente

2. **Configuração dinâmica:**
   - Usa **labels Docker** para configurar rotas
   - Mudanças são aplicadas em tempo real

3. **Let's Encrypt integrado:**
   - Solicita, valida e renova certificados automaticamente
   - Suporta desafios HTTP-01 e DNS-01

4. **Arquitetura de Middleware:**
   - Permite adicionar autenticação, rate limiting, redirects
   - Compõe funcionalidades sem modificar aplicações

**Como Traefik descobre serviços:**

```yaml
# Coolify adiciona esses labels automaticamente:
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.meuapp.rule=Host(`meuapp.com`)"
  - "traefik.http.routers.meuapp.entrypoints=websecure"
  - "traefik.http.routers.meuapp.tls.certresolver=letsencrypt"
  - "traefik.http.services.meuapp.loadbalancer.server.port=8080"
```

**Traefik lê essas labels e cria rotas dinamicamente:**

```
Host: meuapp.com → Container "meuapp" porta 8080
```

### B.3 Sistema de roteamento de domínios e subdomínios

**Traefik usa "routers" para mapear requisições:**

```
Router = Regra de roteamento + Configuração SSL + Middlewares
```

**Exemplo de configuração gerada pelo Coolify:**

```yaml
# Arquivo dinâmico do Traefik (/data/coolify/proxy/dynamic/)
http:
  routers:
    esus-webserver:
      rule: "Host(`esus.exemplo.com`)"
      service: esus-webserver
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt
        domains:
          - main: esus.exemplo.com

  services:
    esus-webserver:
      loadBalancer:
        servers:
          - url: "http://esus-docker-webserver-1:8080"
```

**Como funciona internamente:**

1. **Cliente acessa:** `https://esus.exemplo.com`

2. **Traefik recebe no entrypoint "websecure"** (porta 443)

3. **Traefik verifica as regras dos routers:**
   ```
   Host header == "esus.exemplo.com"? ✅
   ```

4. **Traefik encaminha para o service "esus-webserver":**
   ```
   http://esus-docker-webserver-1:8080
   ```

5. **Container processa e retorna resposta**

**Suporte a múltiplos domínios:**

```yaml
# Traefik suporta múltiplas regras:
rule: "Host(`app.com`) || Host(`www.app.com`) || Host(`api.app.com`)"

# Ou routers separados:
router-main:
  rule: "Host(`app.com`)"
router-api:
  rule: "Host(`api.app.com`) && PathPrefix(`/v1`)"
```

### B.4 Como funciona o mapeamento de portas internas vs externas

**Conceito crucial:**

```
┌──────────────────────────────────────────────────────┐
│  Porta EXTERNA (Traefik)   →   Porta INTERNA (Container)  │
│         80/443              →          8080               │
└──────────────────────────────────────────────────────┘
```

**Fluxo detalhado:**

```
Cliente
  ↓ https://app.com (porta 443)
  ↓
Traefik (escuta porta 443)
  ↓ Descriptografa SSL
  ↓ Verifica roteamento
  ↓ http://webserver:8080 (rede Docker)
  ↓
Container "webserver"
  ↓ Aplicação escuta na porta 8080 DENTRO do container
  ↓ Processa requisição
  ↓
Resposta (mesmo caminho inverso)
```

**Por que isso funciona?**

1. **Traefik está na mesma rede Docker:**
   ```yaml
   networks:
     - coolify-network
   ```

2. **Docker DNS resolve nomes de serviços:**
   ```
   "webserver" → IP interno do container (ex: 172.18.0.5)
   ```

3. **Portas internas são acessíveis dentro da rede Docker:**
   ```
   Container expõe porta 8080 APENAS na rede interna
   Não expõe no host (sem "ports:" no docker-compose)
   ```

**Vantagens dessa arquitetura:**

- ✅ Segurança: portas internas não expostas ao mundo
- ✅ Flexibilidade: múltiplos serviços na mesma porta interna (8080)
- ✅ Simplicidade: aplicação não precisa saber sobre SSL ou roteamento

---

## C. Gerenciamento de Portas no Coolify

### C.1 Como o Coolify expõe portas de containers

**Fonte:** https://coolify.io/docs/knowledge-base/docker/compose

**Regra fundamental do Coolify:**

> **NÃO adicione `ports:` no seu docker-compose.yml quando usar Coolify!**

**Por quê?**

Coolify tem 3 formas de expor serviços:

#### **1. Domain-Based Routing (Recomendado)**

```yaml
# docker-compose.yml
services:
  webserver:
    image: myapp:latest
    expose:
      - "8080"
    # SEM "ports:" !!!
```

```
Coolify UI:
  Service: webserver
  Domain: app.exemplo.com:8080
```

**O que acontece:**
- Traefik detecta o serviço via labels
- Cria rota: `app.exemplo.com` → `webserver:8080`
- SSL automático (Let's Encrypt)
- Porta externa: 443 (HTTPS) ou 80 (HTTP)

#### **2. Port Mapping (Casos específicos)**

```yaml
# docker-compose.yml
services:
  database:
    image: postgres:13
    ports:
      - "5432:5432"  # Expõe no host
```

**Quando usar:**
- Acesso direto ao banco de dados (desenvolvimento)
- Serviços que NÃO passam pelo Traefik (TCP puro)

**Problema:**
- Porta fica FIXA no host
- Precisa reiniciar container para mudar
- Conflitos se outra aplicação usar a mesma porta

#### **3. Public Port (Proxy TCP dinâmico)**

```
Coolify UI:
  Service: database
  Public Port: 15432
```

**O que acontece:**
- Coolify inicia um **proxy NGINX TCP**
- Proxy escuta na porta 15432 do host
- Encaminha para `database:5432` internamente

**Vantagens:**
- Porta pode ser mudada sem reiniciar o container
- Múltiplas instâncias podem ter portas públicas diferentes
- Gerenciamento centralizado no Coolify

### C.2 Diferença entre portas internas do container e portas expostas

**Conceitos:**

| Termo | Significado | Exemplo |
|-------|-------------|---------|
| **Porta interna** | Porta que a aplicação escuta DENTRO do container | App Node.js escuta em `0.0.0.0:3000` |
| **EXPOSE** | Documenta qual porta está disponível (não expõe no host) | `EXPOSE 3000` no Dockerfile |
| **ports:** | Mapeia porta do container → host | `3000:3000` (host:container) |
| **Porta externa** | Porta acessível de fora do servidor | Porta 443 (HTTPS) do Traefik |

**Exemplo prático:**

```dockerfile
# Dockerfile
FROM node:18
WORKDIR /app
COPY . .
RUN npm install
EXPOSE 3000              # Documentação (não tem efeito real)
CMD ["node", "server.js"]  # App escuta em 0.0.0.0:3000
```

```yaml
# docker-compose.yml (INCORRETO para Coolify)
services:
  app:
    build: .
    ports:
      - "3000:3000"  # ❌ NÃO FAZER NO COOLIFY
```

```yaml
# docker-compose.yml (CORRETO para Coolify)
services:
  app:
    build: .
    expose:
      - "3000"  # ✅ Apenas documenta
```

**O que o Coolify faz:**

1. Lê `expose: 3000`
2. Adiciona labels Traefik:
   ```yaml
   labels:
     - "traefik.http.services.app.loadbalancer.server.port=3000"
   ```
3. Traefik encaminha: `https://app.com` → `http://app:3000`

### C.3 Como configurar corretamente o EXPOSE no Dockerfile

**EXPOSE é DOCUMENTAÇÃO, não funcionalidade:**

```dockerfile
# ✅ CORRETO
EXPOSE 8080

# ✅ Múltiplas portas
EXPOSE 8080 8443

# ❌ INCORRETO (não faz sentido)
EXPOSE 8080:80  # Sintaxe de mapeamento não existe aqui
```

**Quando o EXPOSE é usado:**

1. **Documentação:** Indica qual porta o desenvolvedor espera que esteja disponível
2. **`docker run -P`:** Mapeia automaticamente portas expostas para portas aleatórias do host
3. **Ferramentas:** Coolify, Kubernetes, etc. podem ler essa info

**EXPOSE NÃO:**
- Expõe a porta no host
- Configura roteamento
- Abre firewall

**Melhor prática:**

```dockerfile
# Sempre documente a porta que a aplicação usa
EXPOSE 8080

# Se múltiplos serviços:
EXPOSE 8080   # HTTP
EXPOSE 9090   # Métricas (Prometheus)
EXPOSE 50051  # gRPC
```

### C.4 Como o docker-compose.yml deve declarar portas para o Coolify

**Regra de ouro:**

```yaml
# ✅ PARA APLICAÇÕES WEB (HTTP/HTTPS):
services:
  webserver:
    image: myapp
    expose:
      - "8080"
    # SEM "ports:"
    # Coolify gerencia roteamento via Traefik

# ✅ PARA SERVIÇOS TCP/UDP (banco de dados, etc):
services:
  database:
    image: postgres:13
    # Opção 1: Não expor (apenas interno)
    # (outros containers acessam via "database:5432")

    # Opção 2: Expor no host (desenvolvimento)
    ports:
      - "5432:5432"

    # Opção 3: Usar "Public Port" no Coolify UI
    # (recomendado para produção)
```

**Exemplo completo (eSUS-Docker):**

```yaml
services:
  database:
    image: esus_database:1.0.0
    # Porta NÃO exposta (comunicação interna apenas)
    # Outros containers acessam via: jdbc:postgresql://database:5432/esus

  webserver:
    image: esus_webserver:5.2.31
    expose:
      - "8080"  # Apenas documenta
    # Coolify configura: esus.exemplo.com → webserver:8080
    depends_on:
      - database
```

### C.5 Por que algumas configurações de porta funcionam e outras não

**Cenário 1: Porta não exposta corretamente**

```yaml
# ❌ PROBLEMA:
services:
  app:
    image: myapp
    # Falta "expose:" ou "ports:"
```

**Resultado:**
- Traefik não sabe qual porta acessar
- Erro: "Gateway Timeout" ou "Bad Gateway"

**Solução:**
```yaml
expose:
  - "8080"
```

---

**Cenário 2: Porta exposta incorretamente no host**

```yaml
# ❌ PROBLEMA:
services:
  app:
    image: myapp
    ports:
      - "8080:8080"  # Expõe no host
```

**Resultado:**
- Funciona, MAS cria conflitos:
  - Outros containers não podem usar porta 8080 do host
  - Traefik pode acessar diretamente via `localhost:8080`
  - Bypassa o roteamento do Coolify

**Solução:**
```yaml
expose:
  - "8080"  # Apenas rede interna
```

---

**Cenário 3: Aplicação escuta em 127.0.0.1**

```dockerfile
# ❌ PROBLEMA:
CMD ["node", "server.js"]
```

```javascript
// server.js
app.listen(3000, '127.0.0.1');  // Escuta APENAS em localhost
```

**Resultado:**
- Traefik não consegue acessar (127.0.0.1 é local ao container)
- Erro: "Connection refused"

**Solução:**
```javascript
app.listen(3000, '0.0.0.0');  // Escuta em TODAS as interfaces
```

---

**Cenário 4: Porta no label Traefik diferente da aplicação**

```yaml
services:
  app:
    image: myapp
    expose:
      - "3000"  # App escuta na 3000
    labels:
      - "traefik.http.services.app.loadbalancer.server.port=8080"  # ❌ Errado!
```

**Resultado:**
- Traefik tenta acessar porta 8080
- Aplicação não responde
- Erro: "Connection refused"

**Solução:**
- Coolify gerencia labels automaticamente, mas se configurar manualmente:
```yaml
- "traefik.http.services.app.loadbalancer.server.port=3000"
```

---

**Cenário 5: Healthcheck na porta errada**

```yaml
services:
  app:
    image: myapp
    expose:
      - "8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000"]  # ❌ Porta errada!
```

**Resultado:**
- Container nunca fica "healthy"
- Coolify não considera o serviço pronto

**Solução:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080"]  # ✅ Porta correta
```

---

## D. SSL Automático

### D.1 Como o Coolify provisiona certificados SSL automaticamente

**Fonte:** https://coolify.io/docs + pesquisa sobre Traefik + Let's Encrypt

**Fluxo completo:**

```
1. Usuário configura domínio no Coolify:
   ✅ https://app.exemplo.com

2. Coolify adiciona label ao container:
   labels:
     - "traefik.http.routers.app.tls.certresolver=letsencrypt"

3. Cliente faz primeira requisição HTTPS:
   https://app.exemplo.com

4. Traefik detecta que não tem certificado:
   ❌ Certificado para "app.exemplo.com" não encontrado

5. Traefik inicia desafio Let's Encrypt (HTTP-01):

   a) Let's Encrypt envia desafio:
      "Prove que você controla app.exemplo.com"

   b) Let's Encrypt acessa:
      http://app.exemplo.com/.well-known/acme-challenge/TOKEN

   c) Traefik responde automaticamente com token correto

   d) Let's Encrypt valida:
      ✅ Domínio confirmado!

   e) Let's Encrypt emite certificado:
      - Certificado público (.crt)
      - Chave privada (.key)

6. Traefik salva certificado:
   /data/coolify/proxy/letsencrypt/acme.json

7. Traefik configura SSL:
   ✅ Certificado válido por 90 dias

8. Cliente recebe resposta HTTPS segura:
   🔒 Conexão segura
```

**Renovação automática:**

```
Traefik verifica certificados a cada 24 horas:

Se certificado expira em < 30 dias:
  ↓
Traefik solicita renovação (mesmo processo)
  ↓
Let's Encrypt valida domínio novamente
  ↓
Novo certificado emitido
  ↓
Traefik aplica novo certificado SEM downtime
```

### D.2 Qual sistema usa (Let's Encrypt, Caddy, Traefik, etc.)

**Coolify usa:** **Traefik com Let's Encrypt**

**Por quê Traefik?**

1. **ACME nativo:** Protocolo Let's Encrypt integrado
2. **Renovação automática:** Sem scripts cron externos
3. **Zero downtime:** Aplica novos certificados sem reiniciar
4. **Wildcard support:** Certificados `*.exemplo.com` via DNS-01

**Comparação com outras soluções:**

| Solução | Certificados | Renovação | Integração Docker | Complexidade |
|---------|-------------|-----------|-------------------|--------------|
| **Traefik** | Let's Encrypt | ✅ Automática | ✅ Nativa | Baixa |
| **Caddy** | Let's Encrypt | ✅ Automática | ⚠️ Manual | Média |
| **NGINX + Certbot** | Let's Encrypt | ⚠️ Cron job | ❌ Manual | Alta |
| **NGINX + acme.sh** | Let's Encrypt | ⚠️ Cron job | ❌ Manual | Alta |

**Arquitetura do Traefik no Coolify:**

```
/data/coolify/proxy/
├── traefik.yaml          # Configuração estática
├── dynamic/              # Configuração dinâmica (rotas)
│   ├── coolify.yaml     # Gerado pelo Coolify
│   └── custom.yaml      # Configurações customizadas
└── letsencrypt/
    └── acme.json        # Certificados (criptografados)
```

### D.3 Requisitos para SSL automático funcionar

**Checklist:**

1. ✅ **Domínio apontando para o servidor:**
   ```
   app.exemplo.com → A record → IP do servidor
   ```

   Verificar:
   ```bash
   dig app.exemplo.com
   # Deve retornar o IP correto
   ```

2. ✅ **Porta 80 aberta (HTTP):**
   - Let's Encrypt usa desafio HTTP-01
   - Precisa acessar `http://dominio/.well-known/acme-challenge/`

   Verificar:
   ```bash
   curl -I http://app.exemplo.com
   # Deve retornar resposta (mesmo que 404)
   ```

3. ✅ **Porta 443 aberta (HTTPS):**
   - Onde o certificado será usado

   Verificar:
   ```bash
   telnet app.exemplo.com 443
   # Deve conectar
   ```

4. ✅ **Domínio configurado com HTTPS no Coolify:**
   ```
   URL: https://app.exemplo.com (não http://)
   ```

5. ✅ **Traefik rodando:**
   ```bash
   docker ps | grep traefik
   # Deve mostrar container "coolify-proxy"
   ```

6. ✅ **Sem proxies intermediários bloqueando:**
   - Cloudflare: usar modo "DNS Only" durante primeiro certificado
   - Firewalls: permitir tráfego HTTP/HTTPS

7. ✅ **Rate limits Let's Encrypt:**
   - Máximo 5 certificados por semana para o mesmo domínio
   - Máximo 50 domínios por certificado

   Ver: https://letsencrypt.org/docs/rate-limits/

### D.4 Troubleshooting de problemas com SSL

#### **Problema 1: "Certificado não confiável" no navegador**

**Sintomas:**
- ⚠️ Aviso de segurança
- Certificado self-signed

**Causas:**
1. Traefik ainda não obteve certificado (aguardar 1-2 min)
2. Domínio não resolvendo para o servidor
3. Porta 80 bloqueada

**Diagnóstico:**
```bash
# 1. Verificar logs do Traefik:
docker logs coolify-proxy -f

# Procurar por:
# ✅ "certificate obtained successfully"
# ❌ "Unable to obtain ACME certificate"

# 2. Verificar DNS:
dig +short app.exemplo.com
# Deve retornar IP do servidor

# 3. Testar desafio ACME:
curl http://app.exemplo.com/.well-known/acme-challenge/test
# Deve retornar algo (não erro de conexão)
```

**Solução:**
- Aguardar 2-3 minutos após configurar domínio
- Verificar DNS e firewall
- Forçar nova solicitação: remover domínio e adicionar novamente no Coolify

---

#### **Problema 2: Erro "acme: error: 403"**

**Sintomas:**
```
Unable to obtain ACME certificate for domains "app.exemplo.com"
acme: error: 403 :: urn:ietf:params:acme:error:unauthorized
```

**Causas:**
- Let's Encrypt não consegue acessar `/.well-known/acme-challenge/`
- Outro serviço respondendo na porta 80
- Cloudflare em modo proxy (Full SSL)

**Solução:**
```bash
# 1. Testar acesso direto:
curl -v http://IP_DO_SERVIDOR/.well-known/acme-challenge/test

# 2. Se usar Cloudflare:
# - Modo "DNS Only" durante primeira emissão
# - Depois pode voltar para "Proxied"

# 3. Verificar se outro serviço usa porta 80:
sudo netstat -tulpn | grep :80
```

---

#### **Problema 3: Certificado expirando (não renova)**

**Sintomas:**
- Certificado válido mas perto de expirar (< 30 dias)
- Logs mostram falha na renovação

**Diagnóstico:**
```bash
# Ver data de expiração:
echo | openssl s_client -connect app.exemplo.com:443 2>/dev/null | \
  openssl x509 -noout -dates

# Ver logs de renovação:
docker logs coolify-proxy | grep -i renew
```

**Causas:**
1. DNS mudou (domínio não aponta mais para o servidor)
2. Porta 80 bloqueada
3. Rate limit atingido

**Solução:**
```bash
# Forçar renovação:
# 1. Parar Traefik:
docker stop coolify-proxy

# 2. Remover certificados antigos:
sudo rm /data/coolify/proxy/letsencrypt/acme.json

# 3. Reiniciar Traefik:
docker start coolify-proxy

# 4. Traefik solicitará novos certificados
```

---

#### **Problema 4: Wildcard SSL não funciona**

**Sintomas:**
- `*.exemplo.com` não obtém certificado
- Erro "DNS-01 challenge failed"

**Causa:**
- Wildcard requer desafio DNS-01 (não HTTP-01)
- Precisa configurar API do provedor DNS

**Solução:**

**Fonte:** https://coolify.io/docs/knowledge-base/proxy/traefik/wildcard-certs

1. Configurar variáveis de ambiente do provedor DNS no Traefik:

```bash
# Exemplo para Cloudflare:
# Coolify UI → Servers → Proxy → Add Environment Variable

CF_API_EMAIL=email@exemplo.com
CF_DNS_API_TOKEN=seu_token_cloudflare
```

2. Adicionar configuração dinâmica:

```yaml
# /data/coolify/proxy/dynamic/wildcard.yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: email@exemplo.com
      storage: /letsencrypt/acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
```

3. Reiniciar Traefik:
```bash
docker restart coolify-proxy
```

---

#### **Problema 5: "Too many certificates already issued"**

**Sintomas:**
```
acme: error: 429 :: urn:ietf:params:acme:error:rateLimitExceeded
```

**Causa:**
- Rate limit do Let's Encrypt atingido
- Limite: 5 certificados/semana para o mesmo domínio

**Solução:**
```bash
# Verificar quantos certificados foram emitidos:
# https://crt.sh/?q=exemplo.com

# Opções:
# 1. Aguardar 7 dias
# 2. Usar subdomínio diferente temporariamente
# 3. Usar certificado custom (não Let's Encrypt)
```

---

## E. Análise do docker-compose.yml do eSUS-Docker

### E.1 Visão Geral

```yaml
services:
  database:
    # Banco de dados PostgreSQL
  webserver:
    # Aplicação e-SUS PEC
```

**Arquitetura:**

```
Internet (HTTPS)
    ↓
Traefik (gerenciado pelo Coolify)
    ↓
[Rede Docker Interna: coolify-esus-network]
    ↓
webserver:8080 ←→ database:5432
```

### E.2 Análise do Serviço `database`

```yaml
  database:
    image: esus_database:1.0.0
    build: database
```

**Decisão:** Imagem customizada com scripts de backup

**Por quê não usar `postgres:9.6.13-alpine` diretamente?**
- Necessidade de backups automáticos (cron)
- Scripts de inicialização customizados
- AWS CLI para backups S3 (opcional)

**Alternativa (se não precisasse de backups):**
```yaml
  database:
    image: postgres:9.6.13-alpine
```

---

```yaml
    environment:
      - POSTGRES_DB=${POSTGRES_DB:-esus}
      - POSTGRES_USER=${POSTGRES_USER:-postgres}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-esus}
      - BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}
      - S3_BUCKET=${S3_BUCKET:-}
      - AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}
      - AWS_ENDPOINT_URL=${AWS_ENDPOINT_URL:-}
```

**Decisão:** Variáveis com valores padrão (`:-`)

**Sintaxe:**
```bash
${VARIAVEL:-valor_padrao}
# Se VARIAVEL não existir ou estiver vazia, usa valor_padrao
```

**Por quê?**
- ✅ Funciona sem arquivo `.env` (desenvolvimento local)
- ✅ Seguro: credenciais sensíveis ficam vazias por padrão
- ✅ Flexível: Coolify sobrescreve via UI

**O que aconteceria SEM valores padrão:**
```yaml
      - POSTGRES_DB=${POSTGRES_DB}  # ❌ Se não definir, fica vazio!
```
**Resultado:**
- PostgreSQL iniciaria sem nome de banco
- Erro ao tentar conectar

---

```yaml
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ${BACKUP_DIR:-./backups}:/backups
```

**Decisão 1:** Volume nomeado para dados

```yaml
postgres_data:/var/lib/postgresql/data
```

**Por quê volume nomeado e não bind mount?**

| Volume Nomeado | Bind Mount |
|---------------|-----------|
| `postgres_data:/var/lib/...` | `./data:/var/lib/...` |
| ✅ Gerenciado pelo Docker | ⚠️ Depende do filesystem do host |
| ✅ Performance otimizada | ⚠️ Performance pode variar |
| ✅ Portável entre ambientes | ❌ Caminho pode não existir |
| ✅ Backups automáticos (Coolify) | ⚠️ Backups manuais |

**Quando usar bind mount:**
- Desenvolvimento (quer editar arquivos do host)
- Logs (quer acessar facilmente)

**Quando usar volume nomeado:**
- Produção (dados críticos)
- Bancos de dados (performance)

**Decisão 2:** Bind mount para backups

```yaml
${BACKUP_DIR:-./backups}:/backups
```

**Por quê bind mount aqui?**
- ✅ Backups acessíveis diretamente no host
- ✅ Pode fazer `ls ./backups/` no servidor
- ✅ Fácil copiar para outro servidor (rsync, scp)
- ✅ Integração com scripts de backup externos

**Alternativa (volume nomeado):**
```yaml
volumes:
  - postgres_backups:/backups
```
**Problema:** Precisaria usar `docker cp` para acessar backups

---

```yaml
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres} -d ${POSTGRES_DB:-esus}"]
      interval: 10s
      retries: 5
      start_period: 30s
      timeout: 10s
```

**Decisão:** Healthcheck robusto

**Como funciona:**

```
Docker executa comando a cada 10 segundos:
  ↓
pg_isready -U postgres -d esus
  ↓
Verifica se PostgreSQL aceita conexões:
  ✅ Retorno 0: healthy
  ❌ Retorno != 0: unhealthy
  ↓
Após 5 falhas consecutivas: unhealthy
```

**Parâmetros:**
- `interval: 10s` → Verifica a cada 10 segundos
- `retries: 5` → Tolera 5 falhas antes de marcar "unhealthy"
- `start_period: 30s` → Ignora falhas nos primeiros 30s (tempo de inicialização)
- `timeout: 10s` → Comando tem 10s para executar

**Por quê isso é importante?**

```yaml
# No webserver:
depends_on:
  database:
    condition: service_healthy  # Aguarda database estar HEALTHY
```

**Sem healthcheck:**
```yaml
depends_on:
  - database  # Aguarda APENAS o container iniciar (não o PostgreSQL estar pronto)
```

**Resultado SEM healthcheck:**
- Webserver inicia antes do banco estar pronto
- Erros: "Connection refused", "Database does not exist"
- Precisa de retry logic na aplicação

**Com healthcheck:**
- Webserver aguarda banco estar 100% funcional
- Aplicação conecta com sucesso na primeira tentativa

---

```yaml
    restart: unless-stopped
```

**Decisão:** Restart automático

**Políticas disponíveis:**

| Política | Comportamento |
|----------|---------------|
| `no` | Nunca reinicia |
| `always` | Sempre reinicia (mesmo após `docker stop`) |
| `on-failure` | Reinicia apenas se exitcode != 0 |
| `unless-stopped` | Reinicia sempre, EXCETO se parado manualmente |

**Por quê `unless-stopped`?**
- ✅ Reinicia após crash do container
- ✅ Reinicia após reboot do servidor
- ❌ NÃO reinicia se você parar manualmente (`docker stop`)

**Cenário prático:**
```bash
# Banco de dados trava (OOM, bug, etc):
Container status: exited (137)
  ↓
Docker reinicia automaticamente
  ↓
Container status: running

# Você para manualmente para manutenção:
docker stop esus-database
  ↓
Servidor reinicia
  ↓
Container NÃO inicia (você parou explicitamente)
```

---

### E.3 Análise do Serviço `webserver`

```yaml
  webserver:
    image: esus_webserver:5.2.31
    build:
      context: webserver
      args:
        - URL_DOWNLOAD_ESUS=${URL_DOWNLOAD_ESUS:-https://...}
```

**Decisão:** Build arg para URL de download

**Por quê build arg?**

```dockerfile
# webserver/Dockerfile
ARG URL_DOWNLOAD_ESUS
RUN wget "${URL_DOWNLOAD_ESUS}" -O eSUS-AB-PEC.jar
```

**Vantagens:**
- ✅ Versão do e-SUS definida no `.env`
- ✅ Pode mudar versão sem editar Dockerfile
- ✅ Rebuilds pegam nova versão automaticamente

**Alternativa (hardcoded):**
```dockerfile
RUN wget "https://arquivos.esusab.ufsc.br/.../5.3.21/eSUS-AB-PEC.jar"
```
**Problema:** Precisa editar Dockerfile para mudar versão

---

```yaml
    environment:
      - APP_DB_URL=jdbc:postgresql://database:5432/${POSTGRES_DB:-esus}
      - APP_DB_USER=${POSTGRES_USER:-postgres}
      - APP_DB_PASSWORD=${POSTGRES_PASSWORD:-esus}
      - ESUS_TRAINING_MODE=${ESUS_TRAINING_MODE:-false}
```

**Decisão:** Referência ao serviço `database` pelo nome

```yaml
APP_DB_URL=jdbc:postgresql://database:5432/...
                           ^^^^^^^^
                           Nome do serviço
```

**Como isso funciona?**

1. **Docker Compose cria rede interna:**
   ```
   Rede: coolify-esus_default
   ```

2. **Docker DNS resolve nomes de serviços:**
   ```
   "database" → IP interno do container (ex: 172.20.0.2)
   ```

3. **Aplicação conecta:**
   ```java
   jdbc:postgresql://172.20.0.2:5432/esus
   ```

**O que aconteceria se usasse `localhost`?**
```yaml
APP_DB_URL=jdbc:postgresql://localhost:5432/esus  # ❌ ERRADO!
```

**Resultado:**
- "localhost" dentro do container = o próprio container
- PostgreSQL não está rodando no container "webserver"
- Erro: "Connection refused"

**O que aconteceria se usasse IP do host?**
```yaml
APP_DB_URL=jdbc:postgresql://192.168.1.100:5432/esus
```

**Resultado:**
- ⚠️ Funcionaria, MAS:
  - IP pode mudar
  - Precisa expor porta 5432 no host (segurança)
  - Não funciona em ambientes diferentes

**Por quê DNS interno é melhor:**
- ✅ Portável (funciona em qualquer ambiente)
- ✅ Não precisa saber IPs
- ✅ Seguro (porta não exposta no host)

---

```yaml
    expose:
      - "8080"
```

**Decisão:** `expose` ao invés de `ports`

**O que acontece:**

**COM `expose`:**
```
Porta 8080 visível APENAS na rede Docker interna
  ↓
Traefik pode acessar: http://webserver:8080
  ↓
Host NÃO pode acessar: curl http://localhost:8080
  ↓ (bloqueado)
```

**COM `ports`:**
```yaml
ports:
  - "8080:8080"
```

```
Porta 8080 exposta NO HOST
  ↓
Traefik pode acessar: http://webserver:8080
  ↓
Host também pode acessar: curl http://localhost:8080
  ↓ (acessível publicamente)
```

**Por quê `expose` é melhor no Coolify:**

1. **Segurança:**
   - Aplicação NÃO acessível diretamente pela internet
   - Todo tráfego passa pelo Traefik (SSL, autenticação, etc)

2. **Flexibilidade:**
   - Múltiplos projetos podem usar porta 8080 internamente
   - Sem conflitos de porta no host

3. **Arquitetura correta:**
   - Coolify gerencia roteamento (Traefik)
   - Aplicação se preocupa apenas com lógica de negócio

**Quando usar `ports`:**
- Desenvolvimento local (quer acessar diretamente)
- Debug (bypassing o proxy)
- Serviços TCP/UDP (não HTTP)

---

```yaml
    labels:

```

**Observação:** Labels vazias no compose

**Por quê?**

Coolify adiciona labels **automaticamente** durante o deploy:

```yaml
# Labels adicionadas pelo Coolify:
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.esus-webserver.rule=Host(`esus.exemplo.com`)"
  - "traefik.http.routers.esus-webserver.entrypoints=websecure"
  - "traefik.http.routers.esus-webserver.tls=true"
  - "traefik.http.routers.esus-webserver.tls.certresolver=letsencrypt"
  - "traefik.http.services.esus-webserver.loadbalancer.server.port=8080"
  - "coolify.managed=true"
  - "coolify.version=4.0"
  - "coolify.applicationId=xyz123"
```

**Se você adicionar labels manualmente:**
- ⚠️ Coolify pode sobrescrever
- ⚠️ Pode causar conflitos

**Quando adicionar labels customizadas:**
```yaml
labels:
  # Middlewares customizados:
  - "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$..."
  - "traefik.http.routers.esus-webserver.middlewares=auth"

  # Headers de segurança:
  - "traefik.http.middlewares.security.headers.customResponseHeaders.X-Frame-Options=DENY"
```

---

```yaml
    depends_on:
      database:
        condition: service_healthy
```

**Decisão:** Dependência com condição de saúde

**Fluxo de inicialização:**

```
Coolify inicia deploy:
  ↓
1. Docker cria rede
  ↓
2. Docker inicia "database"
  ↓
3. Docker aguarda healthcheck:
   ⏳ starting... (30s start_period)
   ⏳ pg_isready: retrying...
   ✅ pg_isready: accepting connections
   ✅ Status: healthy
  ↓
4. Docker inicia "webserver"
  ↓
5. Webserver conecta ao banco (sucesso!)
```

**Sem `condition: service_healthy`:**

```yaml
depends_on:
  - database  # Aguarda APENAS o container iniciar
```

**Fluxo problemático:**

```
1. Docker inicia "database"
  ↓ (PostgreSQL ainda inicializando...)
2. Docker inicia "webserver" IMEDIATAMENTE
  ↓
3. Webserver tenta conectar:
   ❌ Connection refused
   ❌ Aplicação falha
```

**Alternativas (piores):**

1. **Retry logic na aplicação:**
```java
while (true) {
  try {
    connect();
    break;
  } catch (SQLException e) {
    sleep(5000);
  }
}
```
- ⚠️ Complexidade na aplicação
- ⚠️ Logs poluídos com erros

2. **Script de inicialização com wait:**
```bash
#!/bin/bash
until pg_isready -h database; do
  sleep 1
done
exec java -jar app.jar
```
- ⚠️ Código duplicado em cada serviço
- ⚠️ Healthcheck já faz isso!

**Melhor prática:** `depends_on` + `condition: service_healthy`

---

```yaml
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080 || exit 1"]
      interval: 30s
      retries: 5
      start_period: 120s
      timeout: 10s
```

**Decisão:** Healthcheck HTTP

```bash
curl -f http://localhost:8080
```

**Flags:**
- `-f`: Fail silently (retorna exitcode != 0 em erro HTTP)

**Por quê `localhost:8080`?**
- `localhost` dentro do container = o próprio container ✅
- Verifica se a aplicação está respondendo HTTP

**Por quê `start_period: 120s` (2 minutos)?**

O e-SUS PEC demora para iniciar:
1. Java JVM carrega (~10s)
2. Spring Boot inicializa (~20s)
3. e-SUS inicializa banco (~30s)
4. Migrações de banco (~40s)
5. Pronto para receber requisições (~90s)

**start_period** ignora falhas durante esse tempo (não marca "unhealthy" prematuramente)

**Comparação com database:**
```yaml
# Database:
start_period: 30s  # PostgreSQL inicia rápido

# Webserver:
start_period: 120s  # Java/Spring/e-SUS inicia devagar
```

---

```yaml
    restart: unless-stopped
```

**Mesma decisão do database:** Restart automático, exceto se parado manualmente.

---

### E.4 Decisão: Não expor porta do database

```yaml
  database:
    # SEM "ports:" ou "expose:"
```

**Por quê?**

1. **Segurança:**
   - PostgreSQL NÃO acessível de fora do servidor
   - Apenas containers na mesma rede podem conectar
   - Sem risco de ataques diretos ao banco

2. **Isolamento:**
   - Banco é serviço interno
   - Apenas webserver precisa acessar

3. **Coolify best practice:**
   - Serviços internos não devem ser expostos
   - Se precisar acessar (debug), use "Public Port" na UI

**Como acessar o banco para debug?**

**Opção 1: Port forward local:**
```bash
ssh -L 5432:localhost:5432 user@servidor
# Agora pode conectar: psql -h localhost -U postgres
```

**Opção 2: Exec no container:**
```bash
docker exec -it esus-database psql -U postgres -d esus
```

**Opção 3: Public Port no Coolify:**
```
Coolify UI → database service → Public Port: 15432
# Acessa via: psql -h servidor.com -p 15432 -U postgres
```

---

### E.5 Volumes: Decisões de persistência

```yaml
volumes:
  postgres_data:
    driver: local
```

**Decisão:** Volume nomeado com driver `local`

**O que significa `driver: local`?**
- Dados salvos no filesystem do host
- Localização: `/var/lib/docker/volumes/esus-docker_postgres_data/_data`

**Outras opções de driver:**

| Driver | Uso | Vantagens |
|--------|-----|-----------|
| `local` | Filesystem do host | Simples, rápido |
| `nfs` | Network File System | Compartilhado entre servidores |
| `cifs` | Windows shares | Integração Windows |
| `s3` (plugin) | Amazon S3 | Backups automáticos na cloud |

**Por quê não usar outros drivers?**
- `local` é suficiente para single-server
- Performance melhor
- Coolify cuida de backups via UI

**Onde os dados ficam?**

```bash
# Listar volumes:
docker volume ls
# esus-docker_postgres_data

# Inspecionar:
docker volume inspect esus-docker_postgres_data
# Mountpoint: /var/lib/docker/volumes/esus-docker_postgres_data/_data

# Ver tamanho:
sudo du -sh /var/lib/docker/volumes/esus-docker_postgres_data/_data
# 2.5G
```

**Backup do volume:**
```bash
docker run --rm \
  -v esus-docker_postgres_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/postgres-backup.tar.gz /data
```

---

### E.6 Comparação: Docker puro vs Coolify

**Docker puro (sem Coolify):**

```yaml
services:
  database:
    image: postgres:13
    environment:
      - POSTGRES_PASSWORD=secret123
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"  # Expõe no host

  webserver:
    image: myapp
    environment:
      - DATABASE_URL=postgresql://database:5432/app
    ports:
      - "8080:8080"  # Expõe no host
    depends_on:
      - database

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./certs:/etc/nginx/certs
    depends_on:
      - webserver
```

**Você precisa:**
- ✍️ Configurar NGINX manualmente
- ✍️ Obter certificados SSL (certbot)
- ✍️ Configurar renovação SSL (cron)
- ✍️ Gerenciar portas manualmente
- ✍️ Monitorar containers
- ✍️ Fazer rollback manual
- ✍️ Configurar backups

---

**Com Coolify:**

```yaml
services:
  database:
    image: postgres:13
    environment:
      - POSTGRES_PASSWORD=secret123
    volumes:
      - postgres_data:/var/lib/postgresql/data
    # SEM "ports:" - Coolify gerencia

  webserver:
    image: myapp
    environment:
      - DATABASE_URL=postgresql://database:5432/app
    expose:
      - "8080"
    # SEM "ports:" - Coolify gerencia
    depends_on:
      - database
```

**Coolify faz:**
- ✅ Configura Traefik automaticamente
- ✅ Obtém certificados SSL
- ✅ Renova SSL automaticamente
- ✅ Gerencia portas dinamicamente
- ✅ Monitora containers (UI)
- ✅ Rollback com 1 clique
- ✅ Backups automáticos (opcional)

---

## F. Boas Práticas e Padrões

### F.1 Padrões recomendados pela documentação do Coolify

**Fonte:** https://coolify.io/docs/knowledge-base/docker/compose

#### **1. NÃO use `ports:` para aplicações web**

```yaml
# ❌ ERRADO:
services:
  app:
    image: myapp
    ports:
      - "3000:3000"

# ✅ CORRETO:
services:
  app:
    image: myapp
    expose:
      - "3000"
```

**Razão:** Coolify gerencia roteamento via Traefik. Expor portas manualmente causa conflitos.

---

#### **2. Use variáveis de ambiente com valores padrão**

```yaml
# ✅ CORRETO:
environment:
  - DATABASE_URL=${DATABASE_URL:-postgresql://db:5432/app}
  - REDIS_URL=${REDIS_URL:-redis://redis:6379}

# ❌ EVITAR:
environment:
  - DATABASE_URL=postgresql://db:5432/app  # Hardcoded
```

**Razão:** Flexibilidade entre ambientes (dev, staging, prod). Coolify sobrescreve via UI.

---

#### **3. Sempre defina healthchecks**

```yaml
# ✅ CORRETO:
services:
  app:
    image: myapp
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 40s

# ❌ EVITAR:
services:
  app:
    image: myapp
    # Sem healthcheck
```

**Razão:** Coolify depende de healthchecks para saber quando o serviço está pronto. Sem isso, deploys podem falhar silenciosamente.

---

#### **4. Use `depends_on` com `condition`**

```yaml
# ✅ CORRETO:
services:
  app:
    depends_on:
      database:
        condition: service_healthy
      redis:
        condition: service_started

# ❌ EVITAR:
services:
  app:
    depends_on:
      - database  # Aguarda apenas container iniciar
```

**Razão:** Garante ordem correta de inicialização. Evita race conditions.

---

#### **5. Volumes nomeados para dados persistentes**

```yaml
# ✅ CORRETO:
services:
  database:
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
    driver: local

# ❌ EVITAR:
services:
  database:
    volumes:
      - ./data:/var/lib/postgresql/data  # Bind mount
```

**Razão:** Volumes nomeados são gerenciados pelo Docker. Backups automáticos do Coolify funcionam melhor.

---

#### **6. Use `restart: unless-stopped`**

```yaml
# ✅ CORRETO:
services:
  app:
    restart: unless-stopped

# ❌ EVITAR:
services:
  app:
    restart: always  # Reinicia mesmo após docker stop manual
```

**Razão:** `unless-stopped` respeita paradas manuais (manutenção), mas reinicia automaticamente em crashes.

---

#### **7. Não especifique redes manualmente (a menos que necessário)**

```yaml
# ✅ SIMPLES (Coolify cria automaticamente):
services:
  app:
    image: myapp

# ⚠️ AVANÇADO (apenas se precisar de comunicação inter-stack):
services:
  app:
    networks:
      - coolify-global

networks:
  coolify-global:
    external: true
```

**Razão:** Coolify cria rede isolada para cada stack. Redes manuais são para casos avançados (microserviços).

---

### F.2 Erros comuns ao configurar aplicações no Coolify

#### **Erro 1: Aplicação escuta em 127.0.0.1**

```javascript
// ❌ ERRADO:
app.listen(3000, '127.0.0.1');

// ✅ CORRETO:
app.listen(3000, '0.0.0.0');
```

**Sintoma:** Gateway Timeout / Bad Gateway

**Causa:** Traefik tenta acessar de outra rede Docker, 127.0.0.1 é inacessível.

---

#### **Erro 2: Healthcheck na porta errada**

```yaml
# ❌ ERRADO:
services:
  app:
    expose:
      - "8080"
    healthcheck:
      test: ["CMD", "curl", "http://localhost:3000"]  # Porta errada!

# ✅ CORRETO:
services:
  app:
    expose:
      - "8080"
    healthcheck:
      test: ["CMD", "curl", "http://localhost:8080"]
```

**Sintoma:** Container nunca fica "healthy"

---

#### **Erro 3: Esquecer de adicionar `expose:`**

```yaml
# ❌ ERRADO:
services:
  app:
    image: myapp
    # Falta "expose:"

# ✅ CORRETO:
services:
  app:
    image: myapp
    expose:
      - "3000"
```

**Sintoma:** Coolify não detecta a porta, não configura Traefik

---

#### **Erro 4: Usar `localhost` para comunicação entre serviços**

```yaml
# ❌ ERRADO:
services:
  app:
    environment:
      - DATABASE_URL=postgresql://localhost:5432/db  # ❌

# ✅ CORRETO:
services:
  app:
    environment:
      - DATABASE_URL=postgresql://database:5432/db  # Nome do serviço
```

**Sintoma:** Connection refused

**Causa:** `localhost` dentro do container = o próprio container

---

#### **Erro 5: Domínio não aponta para o servidor**

**Configuração no Coolify:**
```
URL: https://app.exemplo.com
```

**DNS:**
```
app.exemplo.com → 192.168.1.100 (IP errado!)
```

**Sintoma:** Site não carrega, SSL não funciona

**Solução:**
```bash
# Verificar DNS:
dig +short app.exemplo.com
# Deve retornar o IP do servidor Coolify
```

---

#### **Erro 6: Cloudflare em modo proxy (Full SSL)**

**Problema:** Cloudflare intercepta requisições Let's Encrypt

**Solução:**
1. Primeira emissão de certificado: Cloudflare em modo "DNS Only"
2. Após certificado obtido: Pode voltar para "Proxied"

Ou:

1. Usar desafio DNS-01 (wildcard certificates)

---

#### **Erro 7: Build args não passados corretamente**

```yaml
# ❌ ERRADO:
services:
  app:
    build:
      context: .
      args:
        API_KEY: ${API_KEY}  # Não funciona em runtime!

# ✅ CORRETO:
services:
  app:
    build:
      context: .
      args:
        BUILD_VERSION: ${BUILD_VERSION}  # Usado durante build
    environment:
      - API_KEY=${API_KEY}  # Usado em runtime
```

**Causa:** Build args são para build time, environment vars são para runtime.

---

### F.3 Como estruturar projetos para melhor compatibilidade

#### **Estrutura recomendada:**

```
meu-projeto/
├── docker-compose.yml       # Orquestração
├── .env.example            # Template de variáveis
├── README.md               # Documentação
├── COOLIFY.md              # Instruções específicas Coolify
│
├── app/                    # Serviço principal
│   ├── Dockerfile
│   ├── src/
│   └── package.json
│
├── database/               # Serviços auxiliares
│   ├── Dockerfile
│   └── init.sql
│
└── nginx/                  # Configurações (se necessário)
    └── nginx.conf
```

---

#### **docker-compose.yml padrão:**

```yaml
services:
  # Serviços internos (bancos, caches):
  database:
    image: postgres:15
    environment:
      - POSTGRES_PASSWORD=${DB_PASSWORD:-changeme}
    volumes:
      - db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready"]
      interval: 10s
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
    restart: unless-stopped

  # Aplicação principal:
  app:
    build:
      context: ./app
      args:
        - NODE_ENV=${NODE_ENV:-production}
    environment:
      - DATABASE_URL=postgresql://postgres:${DB_PASSWORD:-changeme}@database:5432/app
      - REDIS_URL=redis://redis:6379
      - APP_SECRET=${APP_SECRET}
    expose:
      - "3000"
    depends_on:
      database:
        condition: service_healthy
      redis:
        condition: service_started
    healthcheck:
      test: ["CMD", "wget", "--spider", "http://localhost:3000/health"]
      interval: 30s
      start_period: 60s
    restart: unless-stopped

volumes:
  db_data:
  redis_data:
```

---

#### **.env.example:**

```env
# Database
DB_PASSWORD=changeme

# Application
APP_SECRET=changeme
NODE_ENV=production

# Coolify (opcional)
URL=https://app.exemplo.com
```

---

#### **COOLIFY.md:**

```markdown
# Deploy no Coolify

## Variáveis de ambiente necessárias:

- `DB_PASSWORD`: Senha do PostgreSQL
- `APP_SECRET`: Secret key da aplicação
- `URL`: Domínio da aplicação (ex: https://app.exemplo.com)

## Portas:

- Aplicação expõe porta 3000 (HTTP)

## Healthcheck:

- Endpoint: `/health`
- Deve retornar status 200

## Comandos úteis:

```bash
# Ver logs:
docker compose logs -f app

# Acessar banco:
docker compose exec database psql -U postgres -d app
```
```

---

### F.4 Checklist de deploy no Coolify

**Antes de fazer deploy:**

- [ ] **DNS configurado:**
  ```bash
  dig +short app.exemplo.com
  # Retorna IP do servidor
  ```

- [ ] **docker-compose.yml sem `ports:`:**
  ```yaml
  # ✅ Apenas "expose:"
  expose:
    - "8080"
  ```

- [ ] **Variáveis de ambiente com padrões:**
  ```yaml
  ${VARIAVEL:-valor_padrao}
  ```

- [ ] **Healthchecks configurados:**
  ```yaml
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080"]
  ```

- [ ] **`depends_on` com condições:**
  ```yaml
  depends_on:
    database:
      condition: service_healthy
  ```

- [ ] **Aplicação escuta em `0.0.0.0`:**
  ```javascript
  app.listen(PORT, '0.0.0.0');
  ```

- [ ] **Volumes nomeados para dados:**
  ```yaml
  volumes:
    - db_data:/var/lib/postgresql/data
  ```

- [ ] **`.env.example` documentado:**
  ```env
  # Todas as variáveis necessárias listadas
  ```

---

**Durante o deploy no Coolify:**

1. **Criar projeto:**
   - Add Resource → Docker Compose
   - Conectar repositório Git

2. **Configurar variáveis:**
   - Adicionar variáveis sensíveis (senhas, secrets)
   - Verificar valores padrão do compose

3. **Configurar domínios:**
   - Service: webserver
   - URL: `https://app.exemplo.com`
   - Coolify adiciona labels Traefik automaticamente

4. **Deploy:**
   - Deploy → Aguardar build
   - Verificar logs em tempo real

---

**Após o deploy:**

- [ ] **Verificar containers:**
  ```bash
  docker ps | grep meu-projeto
  # Todos devem estar "Up" e "healthy"
  ```

- [ ] **Verificar SSL:**
  ```bash
  curl -I https://app.exemplo.com
  # HTTP/2 200
  ```

- [ ] **Testar funcionalidade:**
  - Login
  - Operações principais
  - Integração com banco

- [ ] **Verificar logs:**
  ```bash
  docker compose logs -f app
  # Sem erros críticos
  ```

- [ ] **Configurar backups (se aplicável):**
  - Coolify UI → Backups
  - Ou script customizado

---

## Conclusão

Este guia cobriu:

- ✅ **Fundamentos de proxy reverso:** Como requisições são roteadas
- ✅ **Arquitetura interna do Coolify:** Traefik, Docker, redes
- ✅ **Gerenciamento de portas:** Quando usar `expose`, `ports`, ou nada
- ✅ **SSL automático:** Let's Encrypt, troubleshooting
- ✅ **Análise profunda do docker-compose.yml:** Decisões técnicas e alternativas
- ✅ **Boas práticas:** Padrões recomendados e erros comuns

**Conceitos-chave:**

1. **Coolify abstrai complexidade:**
   - Traefik configurado automaticamente
   - SSL gerenciado sem intervenção
   - Roteamento dinâmico via labels

2. **Docker networking:**
   - Serviços comunicam via nomes (DNS interno)
   - Portas internas != Portas externas
   - Segurança por isolamento

3. **Healthchecks são cruciais:**
   - Determinam quando serviços estão prontos
   - Permitem orquestração confiável (`depends_on`)
   - Evitam race conditions

4. **Configuração declarativa:**
   - `docker-compose.yml` = single source of truth
   - Variáveis de ambiente = flexibilidade
   - Labels Traefik = roteamento

**Próximos passos:**

1. Experimente modificar o `docker-compose.yml` do eSUS-Docker
2. Teste diferentes configurações de healthcheck
3. Adicione middleware Traefik (autenticação, rate limiting)
4. Configure backups automáticos para S3
5. Explore redes customizadas para microserviços

---

**Referências:**

- [Documentação Oficial Coolify](https://coolify.io/docs)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Compose Specification](https://docs.docker.com/compose/compose-file/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
