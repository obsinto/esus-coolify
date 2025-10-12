# eSUS-Docker
Implantando o e-SUS PEC em container Docker

## One-Click Deploy (Coolify + Caddy)

Este repositório foi ajustado para permitir deploy com um clique no Coolify e publicação via Caddy.

### Pré-requisitos

- Caddy rodando como container no host, conectado a uma rede Docker externa (ex.: `caddy`).
  - Se utiliza o plugin caddy-docker-proxy: imagem `lucaslorentz/caddy-docker-proxy` e rede `caddy` criada: `docker network create caddy`.
  - Se usa Caddy normal com Caddyfile: também conecte o container do Caddy à rede `caddy`.

### Variáveis importantes

- `ESUS_HOST` (opcional; obrigatório se usar caddy-docker-proxy): domínio público (ex.: `esus.example.com`).
- `URL_DOWNLOAD_ESUS` (opcional): URL do instalador do e-SUS PEC. Por padrão usa 5.4.11.

### Passos (Coolify)

1. Crie um novo Service do tipo "Docker Compose from Git" apontando para este repositório.
2. Em Environment, adicione conforme seu cenário:
   - Se usa caddy-docker-proxy: `ESUS_HOST=esus.example.com`.
   - Opcional: `URL_DOWNLOAD_ESUS=<url-installer>`.
3. Garanta que a rede Docker externa `caddy` exista no host (ou defina `CADDY_DOCKER_NETWORK` com o nome da sua rede). Nosso `docker-compose.yaml` conecta o serviço `webserver` a esta rede para ser acessado pelo Caddy.
4. Clique em Deploy.

O banco inicia, o webserver instala/migra o e-SUS na primeira execução e o Caddy publica automaticamente.

### Se você usa caddy-docker-proxy

- Este stack já inclui labels em `webserver` para publicar em `ESUS_HOST` e fazer reverse proxy para a porta interna 8090.

### Se você usa Caddy com Caddyfile (sem plugin)

No seu `Caddyfile`, adicione algo como:

```
esus.example.com {
  reverse_proxy esus-webserver:8090
}
```

Observações:

- O container do Caddy deve estar conectado à rede `caddy`.
- O serviço `webserver` expõe o alias `esus-webserver` nessa rede para facilitar o proxy.

## Gerando as imagens
--
Primeiro vamos criar a imagem do banco de dados que vai ser baseada no PostgreSQL versão 9.6.13-apine, para isso faça o build da imagem usando o Dockerfile que está na pasta database, entre na pasta e utilize o comando ```sudo docker build -t esus_database:1.0 .```.<br/>
Agora vamos criar a imagem do webserver, primeiro copie o link de download da versão do e-SUS PEC direto do site https://sisaps.saude.gov.br/esus/ nesse exemplo utilizerei o link da versão 5.3.21 https://arquivos.esusab.ufsc.br/PEC/1af9b7ee9c3886bd/5.3.21/eSUS-AB-PEC-5.3.21-Linux64.jar.
Vamos agora fazer o build da imagem entrando na pasta webserver, devemos passar os parâmetros necessários  (```URL_DOWNLOAD_ESUS```, ```APP_DB_URL```, ```APP_DB_USER``` e ```APP_DB_PASSWORD```) para o comando de build.<br/>Exemplo : ```sudo docker build --build-arg=URL_DOWNLOAD_ESUS=https://arquivos.esusab.ufsc.br/PEC/1af9b7ee9c3886bd/5.3.21/eSUS-AB-PEC-5.3.21-Linux64.jar --build-arg=APP_DB_URL=jdbc:postgresql://127.0.0.1:5433/esus --build-arg=APP_DB_USER=postgres --build-arg=APP_DB_PASSWORD=esus -t esus_webserver:1.0 .```<br/>

## Criando as imagens e executando os containers com Docker compose (local/manual)
--
No diretório raiz do projeto execute o comando ``sudo sh build-service.sh`` esse shell script vai criar as imagens e os containers de forma automática utilizando internamente o arquivo ``docker-compose.yml``.<br/>
Esse script shell é necessário apenas para uso local/manual. Em plataformas como o Coolify, **não utilize esse script**; o `docker-compose.yaml` já está preparado para instalar/migrar o e-SUS em tempo de execução sem dependência do banco durante o build.

## Observação
--
Os nomes das imagens, containers e rede são de sua escolha assim como a bindagem da porta do webserver.
