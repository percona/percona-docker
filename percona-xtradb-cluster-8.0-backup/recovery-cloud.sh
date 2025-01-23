#!/bin/bash

set -o errexit
set -o xtrace

LIB_PATH='/usr/lib/pxc'
. ${LIB_PATH}/check-version.sh
. ${LIB_PATH}/vault.sh
. ${LIB_PATH}/aws.sh

# temporary fix for PXB-2784
XBCLOUD_ARGS="--curl-retriable-errors=7 $XBCLOUD_EXTRA_ARGS"

if [ -n "$VERIFY_TLS" ] && [[ $VERIFY_TLS == "false" ]]; then
	XBCLOUD_ARGS="--insecure ${XBCLOUD_ARGS}"
fi

if [ -n "$S3_BUCKET_URL" ]; then
	{ set +x; } 2>/dev/null
	s3_add_bucket_dest
	set -x
	aws $AWS_S3_NO_VERIFY_SSL s3 ls "${S3_BUCKET_URL}"
elif [ -n "${BACKUP_PATH}" ]; then
	XBCLOUD_ARGS="${XBCLOUD_ARGS} --storage=azure"
fi

if [ -n "${AZURE_CONTAINER_NAME}" ]; then
    XBCLOUD_ARGS="${XBCLOUD_ARGS} --azure-container-name=${AZURE_CONTAINER_NAME}"
fi

rm -rf /datadir/*
tmp=$(mktemp --directory /datadir/pxc_sst_XXXX)

destination() {
	if [ -n "${S3_BUCKET_URL}" ]; then
		echo -n "s3://${S3_BUCKET_URL}"
	elif [ -n "${BACKUP_PATH}" ]; then
		echo -n "${BACKUP_PATH}"
	fi
}

xbcloud get --parallel="$(grep -c processor /proc/cpuinfo)" ${XBCLOUD_ARGS} "$(destination).sst_info" | xbstream -x -C "${tmp}" --parallel="$(grep -c processor /proc/cpuinfo)" $XBSTREAM_EXTRA_ARGS
xbcloud get --parallel="$(grep -c processor /proc/cpuinfo)" ${XBCLOUD_ARGS} "$(destination)" | xbstream --decompress -x -C "${tmp}" --parallel="$(grep -c processor /proc/cpuinfo)" $XBSTREAM_EXTRA_ARGS

set +o xtrace
transition_key=$(vault_get "$tmp/sst_info")
if [[ -n $transition_key && $transition_key != null ]]; then
	transition_option="--transition-key=$transition_key"
	master_key_options="--generate-new-master-key"
	echo transition-key exists
fi

echo "+ xtrabackup ${XB_USE_MEMORY+--use-memory=$XB_USE_MEMORY} --prepare ${XB_EXTRA_ARGS} --rollback-prepared-trx \
    --xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin --target-dir=$tmp"

xtrabackup ${XB_USE_MEMORY+--use-memory=$XB_USE_MEMORY} --prepare ${transition_option:+"$transition_option"} ${XB_EXTRA_ARGS} --rollback-prepared-trx \
	--xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin "--target-dir=$tmp"

sed -i '/innodb_undo_directory/d' ${tmp}/backup-my.cnf
echo "using defaults-file ${tmp}/backup-my.cnf"
cat ${tmp}/backup-my.cnf

echo "+ xtrabackup  --defaults-file=${tmp}/backup-my.cnf --defaults-group=mysqld --datadir=/datadir --move-back ${XB_EXTRA_ARGS} \
    --force-non-empty-directories $master_key_options ${transition_option:+"$transition_option"} \
    --keyring-vault-config=/etc/mysql/vault-keyring-secret/keyring_vault.conf --early-plugin-load=keyring_vault.so \
    --xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin --target-dir=$tmp"

xtrabackup \
	--defaults-file=${tmp}/backup-my.cnf \
	--defaults-group=mysqld \
	--datadir=/datadir \
	--move-back ${XB_EXTRA_ARGS} \
	--force-non-empty-directories \
	$master_key_options \
	${transition_option:+"$transition_option"} \
	--keyring-vault-config=/etc/mysql/vault-keyring-secret/keyring_vault.conf \
	--early-plugin-load=keyring_vault.so \
	--xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin \
	--target-dir=$tmp

rm -rf "$tmp"
