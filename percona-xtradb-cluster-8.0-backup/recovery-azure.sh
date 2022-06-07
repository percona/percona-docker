#!/bin/bash

set -o errexit
set -o xtrace

LIB_PATH='/usr/lib/pxc'
. ${LIB_PATH}/check-version.sh
. ${LIB_PATH}/vault.sh

INSECURE_ARG=""
if [ -n "$VERIFY_TLS" ] && [[ $VERIFY_TLS == "false" ]]; then
  INSECURE_ARG="--insecure"
fi

# temporary fix for PXB-2784
CURL_RET_ERRORS_ARG='--curl-retriable-errors=7'

SST_INFO_NAME=sst_info

rm -rf /datadir/*
tmp=$(mktemp --directory /datadir/pxc_sst_XXXX)
xbcloud get ${CURL_RET_ERRORS_ARG} ${INSECURE_ARG} "$BACKUP_PATH.$SST_INFO_NAME" --storage=azure --parallel=10 | xbstream -x -C $tmp --parallel=$(grep -c processor /proc/cpuinfo)
xbcloud get ${CURL_RET_ERRORS_ARG} ${INSECURE_ARG} "$BACKUP_PATH" --storage=azure --parallel=10 | xbstream --decompress -x -C $tmp --parallel=$(grep -c processor /proc/cpuinfo)

set +o xtrace
transition_key=$(vault_get $tmp/sst_info)
if [[ -n $transition_key && $transition_key != null ]]; then
    MYSQL_VERSION=$(parse_ini 'mysql-version' "$tmp/sst_info")
    if compare_versions "$MYSQL_VERSION" '<' '5.7.29' &&
        [[ $MYSQL_VERSION != '5.7.28-31-57.2' ]]; then
         transition_key="\$transition_key"
    fi

    transition_option="--transition-key=$transition_key"
    master_key_options="--generate-new-master-key"
    echo transition-key exists
fi

echo "+ xtrabackup ${XB_USE_MEMORY+--use-memory=$XB_USE_MEMORY} --prepare --rollback-prepared-trx \
    --xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin --target-dir=$tmp"

xtrabackup ${XB_USE_MEMORY+--use-memory=$XB_USE_MEMORY} --prepare $transition_option --rollback-prepared-trx \
    --xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin --target-dir=$tmp

echo "+ xtrabackup --defaults-group=mysqld --datadir=/datadir --move-back \
    --force-non-empty-directories $master_key_options \
    --keyring-vault-config=/etc/mysql/vault-keyring-secret/keyring_vault.conf --early-plugin-load=keyring_vault.so \
    --xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin --target-dir=$tmp"

xtrabackup --defaults-group=mysqld --datadir=/datadir --move-back \
    --force-non-empty-directories $transition_option $master_key_options \
    --keyring-vault-config=/etc/mysql/vault-keyring-secret/keyring_vault.conf --early-plugin-load=keyring_vault.so \
    --xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin --target-dir=$tmp

rm -rf $tmp
