FROM openjdk:17-jdk-bullseye
#argumentos para build
#Link para download do instalador versão Linux.
ARG URL_DOWNLOAD_ESUS="https://arquivos.esusab.ufsc.br/PEC/1af9b7ee9c3886bd/5.3.21/eSUS-AB-PEC-5.3.21-Linux64.jar"
#Configurações de conexão com o banco de dados. Por padrão assume que esteja na máquina host
ARG APP_DB_URL="jdbc:postgresql://host.docker.internal:5433/esus"
ARG APP_DB_USER="postgres"
ARG APP_DB_PASSWORD="esus"

RUN echo " Argumentos da build ->  ${APP_DB_URL} - ${APP_DB_USER} - ${APP_DB_PASSWORD}"

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
RUN apt-get install -y ttf-mscorefonts-installer
#Instala dependências necessárias
RUN apt-get install -y init
RUN apt-get install -y file
RUN apt-get install -y postgresql-client
RUN apt-get install -y curl
RUN apt clean

#Define o fuso horário, coloque o fuso horário de sua região.
RUN rm -rf /etc/localtime
RUN ln -s /usr/share/zoneinfo/Etc/GMT+4 /etc/localtime
#Aplique o mesmo fuso horário do localtime, essa variável de ambiente é necessária para o Java pergar corretamente o fuso.
ENV TZ=Etc/GMT+4

#Copia e dá permissão de execução ao script de inicializacão.
COPY startup.sh /opt
COPY configure-logging.sh /opt
RUN chmod +x /opt/startup.sh /opt/configure-logging.sh

WORKDIR /home/downloads
RUN wget -O eSUS-AB-PEC.jar ${URL_DOWNLOAD_ESUS} --no-check-certificate

# NÃO instalar o eSUS durante o build (banco não está disponível)
# A instalação será feita no startup.sh na primeira execução
# Apenas preservar o JAR para instalação posterior

EXPOSE 8080
ENTRYPOINT ["/opt/startup.sh"]