FROM debian:latest

# Instalar dependencias básicas
RUN apt-get update && apt-get install -y \
    lsb-release apt-transport-https ca-certificates curl gnupg2

# Agregar el repositorio de Sury para PHP 7.4
RUN curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/php.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/php.list

# Instalar PHP 7.4 y demás paquetes necesarios
RUN apt-get update && apt-get install -y \
    sudo make gcc dnsutils unzip php7.4 php7.4-fpm php7.4-mysql mariadb-server \
    openjdk-17-jre-headless openjdk-17-jre default-jdk \
    libpcre3 libpcre3-dev libexpat1 libexpat1-dev \
    libxml2 libxml2-dev libxslt1-dev libxslt1.1 git \
    curl vim wget \
    && rm -rf /var/lib/apt/lists/*

# OpenSSL 1.0.2 para compatibilidad
RUN mkdir /openssl && \
    curl -SL https://www.openssl.org/source/openssl-1.0.2q.tar.gz | tar -xzC /openssl --strip-components=1

RUN cd /openssl && \
    ./config --prefix=/opt/openssl-1.0.2 --openssldir=/etc/ssl \
    shared enable-weak-ssl-ciphers enable-ssl3 enable-ssl3-method enable-ssl2 -Wl,-rpath=/opt/openssl-1.0.2/lib && \
    make && make install

RUN echo "/opt/openssl-1.0.2/lib" > /etc/ld.so.conf.d/openssl-1.0.2.conf && ldconfig

# Apache 2.4 desde fuente
WORKDIR /root

# Descargar y extraer Apache y APR
RUN curl -LO https://archive.apache.org/dist/httpd/httpd-2.4.56.tar.gz && \
    curl -LO https://archive.apache.org/dist/apr/apr-1.7.2.tar.gz && \
    curl -LO https://archive.apache.org/dist/apr/apr-util-1.6.3.tar.gz && \
    tar -xzf httpd-2.4.56.tar.gz && mv httpd-2.4.56 httpd


WORKDIR /root/httpd/srclib

RUN tar -xzf /root/apr-1.7.2.tar.gz && \
    tar -xzf /root/apr-util-1.6.3.tar.gz && \
    ln -s apr-1.7.2 apr && \
    ln -s apr-util-1.6.3 apr-util

WORKDIR /root/httpd

RUN ./configure --prefix=/opt/apache --with-included-apr --with-ssl=/opt/openssl-1.0.2 --enable-ssl && \
    make && make install

# DNAS
WORKDIR /root

RUN git clone https://github.com/corbin-ch/DNASrep.git && \
    mv DNASrep/etc/dnas /etc/dnas && \
    mkdir -p /var/www && \
    mv DNASrep/www/dnas /var/www/dnas && \
    chown -R www-data:www-data /var/www/dnas

# BIOSERVER
RUN git clone https://github.com/corbin-ch/bioserver.git

RUN mkdir -p /var/www/bhof1 /var/www/bhof2 && \
    cp bioserver/bioserv1/www/* /var/www/bhof1 && \
    cp bioserver/bioserv2/www/* /var/www/bhof2 && \
    chown -R www-data:www-data /var/www/bhof1 /var/www/bhof2 && \
    ln -s /var/www/bhof1 /var/www/dnas/00000002 && \
    ln -s /var/www/bhof2 /var/www/dnas/00000010

# Conector MySQL
RUN wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j_8.0.32-1debian11_all.deb && \
    dpkg -i mysql-connector-j_8.0.32-1debian11_all.deb

# Compilar Java (File 1)
WORKDIR /root/bioserver/bioserv1/bioserver
RUN javac -cp /usr/share/java/mysql-connector-j-8.0.32.jar:. *.java

WORKDIR /root/bioserver/bioserv1
RUN mkdir -p bin/bioserver lib && \
    mv bioserver/*.class bin/bioserver && \
    mv bioserver/config.properties . && \
    ln -s /usr/share/java/mysql-connector-j-8.0.32.jar lib/mysql-connector.jar

# Compilar Java (File 2)
WORKDIR /root/bioserver/bioserv2/bioserver
RUN javac -cp /usr/share/java/mysql-connector-j-8.0.32.jar:. *.java

WORKDIR /root/bioserver/bioserv2
RUN mkdir -p bin/bioserver lib && \
    mv bioserver/*.class bin/bioserver && \
    mv bioserver/config.properties . && \
    ln -s /usr/share/java/mysql-connector-j-8.0.32.jar lib/mysql-connector.jar

# Configuración para php-fpm7.4
RUN mkdir -p /run/php && chown www-data:www-data /run/php && chmod 755 /run/php

# Copiar archivos necesarios
COPY ./config/entrypoint.sh /root/
COPY ./config/patch.raw /root/bioserver/bioserv1/patch.raw
COPY ./config/patch.raw /root/bioserver/bioserv2/patch.raw
COPY ./config/end_of_httpd.conf /root/

ENTRYPOINT ["/bin/bash", "/root/entrypoint.sh"]
CMD ["/bin/bash"]
