#!/bin/bash

set -o errexit
set -o xtrace

{ set +x; } 2> /dev/null
echo "+ mc -C /tmp/mc config host add dest "${ENDPOINT:-https://s3.amazonaws.com}" ACCESS_KEY_ID SECRET_ACCESS_KEY"
mc -C /tmp/mc config host add dest "${ENDPOINT:-https://s3.amazonaws.com}" "$ACCESS_KEY_ID" "$SECRET_ACCESS_KEY"
set -x
mc -C /tmp/mc ls "dest/${S3_BUCKET_URL}"

rm -rf /datadir/*
xbcloud get "s3://${S3_BUCKET_URL}.sst_info" --parallel=10 | xbstream -x -C /datadir --parallel=$(grep -c processor /proc/cpuinfo)
xbcloud get "s3://${S3_BUCKET_URL}" --parallel=10 | xbstream -x -C /datadir --parallel=$(grep -c processor /proc/cpuinfo)
xtrabackup --prepare --target-dir=/datadir ${XB_USE_MEMORY+--use-memory=$XB_USE_MEMORY}
