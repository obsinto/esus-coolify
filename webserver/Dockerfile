FROM openjdk:17-jdk-bullseye
#argumentos para build
#Link para download do instalador versão Linux.
ARG URL_DOWNLOAD_ESUS="https://arquivos.esusab.ufsc.br/PEC/26e603822f8adcc4/5.3.28/eSUS-AB-PEC-5.3.28-Linux64.jar"
#Configurações de conexão com o banco de dados são definidas em tempo de execução via variáveis de ambiente (APP_DB_URL, APP_DB_USER, APP_DB_PASSWORD).

#Atualiza a sources.list do Debian para poder instalar as fonts do windows.
RUN cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian bullseye main contrib non-free
deb-src http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian-security/ bullseye-security main contrib non-free
deb-src http://deb.debian.org/debian-security/ bullseye-security main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb-src http://deb.debian.org/debian bullseye-updates main contrib non-free
EOF
RUN apt update
RUN apt-get install -y ttf-mscorefonts-installer wget curl
#Instala o init e o file porque o instalador do ESUS executa esses comandos.
RUN apt-get install -y init
RUN apt-get install -y file
#Instala o cliente PostgreSQL para limpeza de locks do Liquibase e SystemD
RUN apt-get install -y postgresql-client systemd systemd-sysv
RUN apt clean

#Define o fuso horário, coloque o fuso horário de sua região.
RUN rm -rf /etc/localtime
RUN ln -s /usr/share/zoneinfo/Etc/GMT+4 /etc/localtime
#Aplique o mesmo fuso horário do localtime, essa variável de ambiente é necessária para o Java pergar corretamente o fuso.
ENV TZ=Etc/GMT+4

#Copia e dá permissão de execução ao script de inicializacão.
COPY startup.sh /opt
RUN chmod +x /opt/startup.sh

#Configura o serviço SystemD para executar na inicialização
COPY esus.service /etc/systemd/system/
RUN systemctl enable esus.service || true

RUN mkdir -p /opt/bootstrap /opt/e-SUS
WORKDIR /opt/bootstrap
RUN wget -O eSUS-AB-PEC.jar ${URL_DOWNLOAD_ESUS} --no-check-certificate
#Extrai o migrador do banco de dados para ser executado na inicialização.
RUN jar xf eSUS-AB-PEC.jar && cp container/database/migrador.jar /opt/bootstrap/ && rm -rf container

EXPOSE 8080 8090

# SystemD requires this volume
VOLUME ["/sys/fs/cgroup"]

# Use SystemD as init
CMD ["/sbin/init"]
