#!/bin/bash

# Iniciar MariaDB
mysqld_safe --pid-file=mysqld.pid --socket=/run/mysqld/mysqld.sock --log-error=mysqld_error.log &
sleep 5s

if [ ! -f /root/already-configured ]; then
    # OpenSSL
    sed -i '26iLD_LIBRARY_PATH="/opt/openssl-1.0.2/lib:$LD_LIBRARY_PATH"' /opt/apache/bin/envvars

    # Usar IP pasada por variable de entorno o fallback a 127.0.0.1
    IP=${EXTERNAL_IP:-"127.0.0.1"}

    # Reemplazar IP en config.properties
    sed -i "s/{{EXTERNAL_IP}}/${IP}/g" /root/bioserver/bioserv1/config.properties
    sed -i "s/{{EXTERNAL_IP}}/${IP}/g" /root/bioserver/bioserv1/config.properties

    # Configurar Apache
    sed -i '116s/^#//; 120s/^#//; 133s/^#//; 152s/^#//' /opt/apache/conf/httpd.conf
    sed -i 's/User daemon/User www-data/g' /opt/apache/conf/httpd.conf
    sed -i 's/Group daemon/Group www-data/g' /opt/apache/conf/httpd.conf
    cat /root/end_of_httpd.conf >> /opt/apache/conf/httpd.conf

    # Crear base de datos
    mysql -u root < /root/bioserver/bioserv1/database/bioserver.sql
    mysql -u root < /root/bioserver/bioserv2/database/bioserver.sql

    touch /root/already-configured
fi

# Iniciar servicios
/opt/apache/bin/apachectl -d /opt/apache/ -f /opt/apache/conf/httpd.conf -k start -e info
php-fpm7.4 -D

# Servidores de juego
cd /root/bioserver/bioserv1/
EXTERNAL_IP=${EXTERNAL_IP:-"127.0.0.1"} ./run_file1.sh &

cd /root/bioserver/bioserv2/
EXTERNAL_IP=${EXTERNAL_IP:-"127.0.0.1"} ./run_file2.sh

exec /bin/bash
