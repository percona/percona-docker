#!/bin/bash

set -o errexit
set -o xtrace

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

parse_sst_info() {
   local source_path=$1
   local group=$2
   local var=$3
   local reval=""

   reval=$(my_print_defaults -c "$source_path" $group | awk -F= '{if ($1 ~ /_/) { gsub(/_/,"-",$1); print $1"="$2 } else { print $0 }}' | grep -- "--$var=" | cut -d= -f2- | tail -1)

   # use default if we haven't found a value
   if [[ -z $reval ]]; then
      [[ -n $4 ]] && reval=$4
   fi

   echo $reval
}

ping -c1 $RESTORE_SRC_SERVICE || :
rm -rf /datadir/*

socat -u "$SOCAT_OPTS" stdio | xbstream -x -C /datadir --parallel=$(grep -c processor /proc/cpuinfo)
socat -u "$SOCAT_OPTS" stdio | xbstream -x -C /datadir --parallel=$(grep -c processor /proc/cpuinfo)

# xtrabackup --use-memory=750000000 --prepare --binlog-info=ON '--transition-key=$transition_key' --rollback-prepared-trx --xtrabackup-plugin-dir=/usr/bin/pxc_extra/pxb-8.0/lib/plugin --target-dir=/var/lib/mysql//sst-xb-tmpdir
transition_key=$(parse_sst_info "/datadir/sst_info" sst transition-key "")
if [[ -n $transition_key ]]; then
    (xtrabackup --prepare --binlog-info=ON --rollback-prepared-trx --target-dir=/datadir --xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin --transition-key=$transition_key ${XB_USE_MEMORY+--use-memory=$XB_USE_MEMORY}) || sleep infinity
else
    echo "failed to parse transition key"
    exit 1
fi
