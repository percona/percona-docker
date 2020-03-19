#!/bin/bash

set -o errexit
set -o xtrace

parse_sst_info() {
   local source_path=$1
   awk -F "=" '/transition-key/ {print $2}' "$source_path"
}

{ set +x; } 2> /dev/null
echo "+ mc -C /tmp/mc config host add dest "${ENDPOINT:-https://s3.amazonaws.com}" ACCESS_KEY_ID SECRET_ACCESS_KEY"
mc -C /tmp/mc config host add dest "${ENDPOINT:-https://s3.amazonaws.com}" "$ACCESS_KEY_ID" "$SECRET_ACCESS_KEY"
set -x
mc -C /tmp/mc ls "dest/${S3_BUCKET_URL}"

rm -rf /datadir/*
xbcloud get "s3://${S3_BUCKET_URL}.sst_info" --parallel=10 | xbstream -x -C /datadir --parallel=$(grep -c processor /proc/cpuinfo)
xbcloud get "s3://${S3_BUCKET_URL}" --parallel=10 | xbstream -x -C /datadir --parallel=$(grep -c processor /proc/cpuinfo)

transition_key=$(parse_sst_info "/datadir/sst_info")
if [[ -n $transition_key ]]; then
    encrypt_prepare_options="--transition-key=\$transition_key"
    xtrabackup ${XB_USE_MEMORY+--use-memory=$XB_USE_MEMORY} --prepare --binlog-info=ON $encrypt_prepare_options --rollback-prepared-trx --xtrabackup-plugin-dir=/usr/lib64/xtrabackup/plugin --target-dir=/datadir
else
    xtrabackup --prepare --target-dir=/datadir ${XB_USE_MEMORY+--use-memory=$XB_USE_MEMORY}
fi
