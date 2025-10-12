# Fix: Erro "port is already allocated"

## Erro
```
Error response from daemon: driver failed programming external connectivity
Bind for 0.0.0.0:8080 failed: port is already allocated
```

## Causa
A porta 8080 já está sendo usada por outro container.

## Soluções

### Solução 1: Mudar a porta (RECOMENDADO)

No Coolify, adicione a variável de ambiente:

```env
WEB_PORT=8081
```

Ou escolha outra porta disponível: 8082, 9000, etc.

Depois faça **Redeploy**.

### Solução 2: Parar containers na porta 8080

Se você tem acesso SSH ao servidor:

```bash
# Ver quem está usando a porta 8080
docker ps | grep 8080

# Parar o container
docker stop <container-id>

# Ou parar todos os containers do eSUS antigos
docker ps -a | grep webserver | awk '{print $1}' | xargs docker stop
docker ps -a | grep webserver | awk '{print $1}' | xargs docker rm
```

### Solução 3: Via Coolify (mais seguro)

1. No Coolify, vá em **Resources**
2. Procure por recursos antigos/parados do eSUS
3. Delete os recursos antigos
4. Faça **Redeploy** do recurso atual

## Prevenção

Sempre configure `WEB_PORT` nas variáveis de ambiente para evitar conflitos:

```env
WEB_PORT=8081
POSTGRES_PASSWORD=SuaSenhaSegura
```

## Verificar se deu certo

Após o redeploy com porta diferente:

```bash
# No servidor
curl http://localhost:8081

# Ou no navegador
http://seu-dominio:8081
```
