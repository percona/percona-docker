#!/bin/bash

set -o errexit
set -o xtrace

pwd=$(realpath $(dirname $0))
. ${pwd}/vault.sh

SOCAT_OPTS="TCP:${RESTORE_SRC_SERVICE}:3307,retry=30"
function check_ssl() {
    CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    if [ -f /var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt ]; then
        CA=/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt
    fi
    SSL_DIR=${SSL_DIR:-/etc/mysql/ssl}
    if [ -f ${SSL_DIR}/ca.crt ]; then
        CA=${SSL_DIR}/ca.crt
    fi
    SSL_INTERNAL_DIR=${SSL_INTERNAL_DIR:-/etc/mysql/ssl-internal}
    if [ -f ${SSL_INTERNAL_DIR}/ca.crt ]; then
        CA=${SSL_INTERNAL_DIR}/ca.crt
    fi

    KEY=${SSL_DIR}/tls.key
    CERT=${SSL_DIR}/tls.crt
    if [ -f ${SSL_INTERNAL_DIR}/tls.key -a -f ${SSL_INTERNAL_DIR}/tls.crt ]; then
        KEY=${SSL_INTERNAL_DIR}/tls.key
        CERT=${SSL_INTERNAL_DIR}/tls.crt
    fi

    if [ -f "$CA" -a -f "$KEY" -a -f "$CERT" ]; then
        SOCAT_OPTS="openssl-connect:${RESTORE_SRC_SERVICE}:3307,cert=${CERT},key=${KEY},cafile=${CA},verify=1,commonname='',retry=30"
    fi
}

check_ssl
ping -c1 $RESTORE_SRC_SERVICE || :
rm -rf /datadir/*

socat -u "$SOCAT_OPTS" stdio >/datadir/sst_info
socat -u "$SOCAT_OPTS" stdio | xbstream -x -C /datadir --parallel=$(grep -c processor /proc/cpuinfo)

set +o xtrace
transition_key=$(vault_get /datadir/sst_info)
if [[ -n $transition_key ]]; then
    encrypt_prepare_options="--transition-key=\$transition_key"
    echo transition-key exists
fi
echo + xtrabackup ${XB_USE_MEMORY+--use-memory=$XB_USE_MEMORY} --prepare --binlog-info=ON --rollback-prepared-trx --xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin --target-dir=/datadir
xtrabackup ${XB_USE_MEMORY+--use-memory=$XB_USE_MEMORY} --prepare --binlog-info=ON $encrypt_prepare_options --rollback-prepared-trx --xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin --target-dir=/datadir
