#!/bin/bash

set -o errexit
set -o xtrace

LIB_PATH='/usr/lib/pxc'
. ${LIB_PATH}/check-version.sh
. ${LIB_PATH}/vault.sh

# temporary fix for PXB-2784
XBCLOUD_ARGS='--curl-retriable-errors=7'

MC_ARGS='-C /tmp/mc'

if [ -n "$VERIFY_TLS" ] && [[ $VERIFY_TLS == "false" ]]; then
	XBCLOUD_ARGS="${XBCLOUD_ARGS} --insecure"
	MC_ARGS="${MC_ARGS} --insecure"
fi

if [ -n "$S3_BUCKET_URL" ]; then
	{ set +x; } 2>/dev/null
	echo "+ mc ${MC_ARGS} config host add dest ${ENDPOINT:-https://s3.amazonaws.com} ACCESS_KEY_ID SECRET_ACCESS_KEY"
	mc ${MC_ARGS} config host add dest "${ENDPOINT:-https://s3.amazonaws.com}" "$ACCESS_KEY_ID" "$SECRET_ACCESS_KEY"
	set -x
	mc ${MC_ARGS} ls "dest/${S3_BUCKET_URL}"
elif [ -n "${AZURE_CONTAINER_NAME}" ]; then
	XBCLOUD_ARGS="${XBCLOUD_ARGS} --storage=azure"
fi

rm -rf /datadir/*
tmp=$(mktemp --directory /datadir/pxc_sst_XXXX)

destination() {
	if [ -n "${S3_BUCKET_URL}" ]; then
		echo -n "s3://${S3_BUCKET_URL}"
	elif [ -n "${AZURE_CONTAINER_NAME}" ]; then
		echo -n "${BACKUP_PATH}"
	fi
}

xbcloud get ${XBCLOUD_ARGS} "$(destination).sst_info" --parallel=10 | xbstream -x -C "${tmp}" --parallel="$(grep -c processor /proc/cpuinfo)"
xbcloud get ${XBCLOUD_ARGS} "$(destination)" --parallel=10 | xbstream --decompress -x -C "${tmp}" --parallel="$(grep -c processor /proc/cpuinfo)"

set +o xtrace
transition_key=$(vault_get "$tmp/sst_info")
if [[ -n $transition_key && $transition_key != null ]]; then
	transition_option="--transition-key=$transition_key"
	master_key_options="--generate-new-master-key"
	echo transition-key exists
fi

echo "+ xtrabackup ${XB_USE_MEMORY+--use-memory=$XB_USE_MEMORY} --prepare --rollback-prepared-trx \
    --xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin --target-dir=$tmp"

xtrabackup ${XB_USE_MEMORY+--use-memory=$XB_USE_MEMORY} --prepare ${transition_option:+"$transition_option"} --rollback-prepared-trx \
	--xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin "--target-dir=$tmp"

echo "+ xtrabackup --defaults-group=mysqld --datadir=/datadir --move-back \
    --force-non-empty-directories $master_key_options \
    --keyring-vault-config=/etc/mysql/vault-keyring-secret/keyring_vault.conf --early-plugin-load=keyring_vault.so \
    --xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin --target-dir=$tmp"

xtrabackup --defaults-group=mysqld --datadir=/datadir --move-back \
	--force-non-empty-directories ${transition_option:+"$transition_option"} $master_key_options \
	--keyring-vault-config=/etc/mysql/vault-keyring-secret/keyring_vault.conf --early-plugin-load=keyring_vault.so \
	--xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin "--target-dir=$tmp"

rm -rf "$tmp"
