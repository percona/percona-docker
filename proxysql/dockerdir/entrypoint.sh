#!/bin/bash

set -o xtrace

function mysql_root_exec() {
  local server="$1"
  local query="$2"
  MYSQL_PWD=${MYSQL_ROOT_PASSWORD:-password} timeout 600 mysql -h "${server}" -uroot -s -NB -e "${query}"
}

function get_cipher() {
    local h="$1"
    local cipher=""
    while [ -z "$cipher" ]
    do
        cipher=$(mysql_root_exec "$h" 'SHOW SESSION STATUS LIKE "Ssl_cipher"' | awk '{print$2}')
        sleep 1
    done
    echo $cipher
}

PROXY_CFG=/etc/proxysql/proxysql.cnf
PROXY_ADMIN_CFG=/etc/proxysql-admin.cnf

MYSQL_ROOT_PASSWORD_ESCAPED=$(sed 's/[\*\.\@\&\#\?\!]/\\&/g' <<<"${MYSQL_ROOT_PASSWORD}")

sed "s/\"admin:admin\"/\"${PROXY_ADMIN_USER:-admin}:${PROXY_ADMIN_PASSWORD:-admin}\"/g"  ${PROXY_CFG} 1<> ${PROXY_CFG}
sed "s/cluster_username=\"admin\"/cluster_username=\"${PROXY_ADMIN_USER:-admin}\"/g"     ${PROXY_CFG} 1<> ${PROXY_CFG}
sed "s/cluster_password=\"admin\"/cluster_password=\"${PROXY_ADMIN_PASSWORD:-admin}\"/g" ${PROXY_CFG} 1<> ${PROXY_CFG}
sed "s/monitor_password=\"monitor\"/monitor_password=\"${MONITOR_PASSWORD:-monitor}\"/g" ${PROXY_CFG} 1<> ${PROXY_CFG}
sed "s/PROXYSQL_USERNAME='admin'/PROXYSQL_USERNAME='${PROXY_ADMIN_USER:-admin}'/g"       ${PROXY_ADMIN_CFG} 1<> ${PROXY_ADMIN_CFG}
sed "s/PROXYSQL_PASSWORD='admin'/PROXYSQL_PASSWORD='${PROXY_ADMIN_PASSWORD:-admin}'/g"   ${PROXY_ADMIN_CFG} 1<> ${PROXY_ADMIN_CFG}
sed "s/CLUSTER_USERNAME='admin'/CLUSTER_USERNAME='root'/g"                               ${PROXY_ADMIN_CFG} 1<> ${PROXY_ADMIN_CFG}
sed "s/CLUSTER_PASSWORD='admin'/CLUSTER_PASSWORD='$MYSQL_ROOT_PASSWORD_ESCAPED'/g"               ${PROXY_ADMIN_CFG} 1<> ${PROXY_ADMIN_CFG}
sed "s/MONITOR_USERNAME='monitor'/MONITOR_USERNAME='monitor'/g"                          ${PROXY_ADMIN_CFG} 1<> ${PROXY_ADMIN_CFG}
sed "s/MONITOR_PASSWORD='monitor'/MONITOR_PASSWORD='${MONITOR_PASSWORD:-monitor}'/g"     ${PROXY_ADMIN_CFG} 1<> ${PROXY_ADMIN_CFG}

## SSL/TLS support
CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
if [ -f "/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt" ]; then
    CA=/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt
fi
SSL_DIR=${SSL_DIR:-/etc/proxysql/ssl}
if [ -f "${SSL_DIR}/ca.crt" ]; then
    CA=${SSL_DIR}/ca.crt
fi
SSL_INTERNAL_DIR=${SSL_INTERNAL_DIR:-/etc/proxysql/ssl-internal}
if [ -f "${SSL_INTERNAL_DIR}/ca.crt" ]; then
    CA=${SSL_INTERNAL_DIR}/ca.crt
fi

KEY=${SSL_DIR}/tls.key
CERT=${SSL_DIR}/tls.crt
if [ -f "${SSL_INTERNAL_DIR}/tls.key" ] && [ -f "${SSL_INTERNAL_DIR}/tls.crt" ]; then
    KEY=${SSL_INTERNAL_DIR}/tls.key
    CERT=${SSL_INTERNAL_DIR}/tls.crt
fi

if [ -f "$CA" ] && [ -f "$KEY" ] && [ -f "$CERT" ] && [ -n "$PXC_SERVICE" ]; then
    cipher=$(get_cipher "$PXC_SERVICE")

    sed "s^have_ssl=false^have_ssl=true^"                   ${PROXY_CFG} 1<> ${PROXY_CFG}
    sed "s^ssl_p2s_ca=\"\"^ssl_p2s_ca=\"$CA\"^"             ${PROXY_CFG} 1<> ${PROXY_CFG}
    sed "s^ssl_p2s_ca=\"\"^ssl_p2s_ca=\"$CA\"^"             ${PROXY_CFG} 1<> ${PROXY_CFG}
    sed "s^ssl_p2s_key=\"\"^ssl_p2s_key=\"$KEY\"^"          ${PROXY_CFG} 1<> ${PROXY_CFG}
    sed "s^ssl_p2s_cert=\"\"^ssl_p2s_cert=\"$CERT\"^"       ${PROXY_CFG} 1<> ${PROXY_CFG}
    sed "s^ssl_p2s_cipher=\"\"^ssl_p2s_cipher=\"$cipher\"^" ${PROXY_CFG} 1<> ${PROXY_CFG}
fi

if [ -f "${SSL_DIR}/tls.key" ] && [ -f "${SSL_DIR}/tls.crt" ]; then
    cp "${SSL_DIR}/tls.key" /var/lib/proxysql/proxysql-key.pem
    cp "${SSL_DIR}/tls.crt" /var/lib/proxysql/proxysql-cert.pem
fi
if [ -f "${SSL_DIR}/ca.crt" ]; then
    cp "${SSL_DIR}/ca.crt" /var/lib/proxysql/proxysql-ca.pem
fi

exec "$@"
