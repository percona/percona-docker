#!/bin/bash

set -o errexit

SST_INFO_NAME=sst_info
CURL_RET_ERRORS_ARG='--curl-retriable-errors=7'

INSECURE_ARG=""
if [ -n "$VERIFY_TLS" ] && [[ $VERIFY_TLS == "false" ]]; then
  INSECURE_ARG="--insecure"
fi

S3_BUCKET_PATH=${S3_BUCKET_PATH:-$PXC_SERVICE-$(date +%F-%H-%M)-xtrabackup.stream}

log() {
    { set +x; } 2>/dev/null
    local level=$1
    local message=$2
    local now=$(date '+%F %H:%M:%S')

    echo "${now} [${level}] ${message}"
    set -x
}

function is_object_exist() {
    local bucket="$1"
    local object="$2"

    if [[ -n "$(mc -C /tmp/mc ${INSECURE_ARG} --json ls  "dest/$bucket/$object" | jq '.status')" ]]; then
        return 1
    fi
}

function mc_add_bucket_dest() {
    echo "+ mc -C /tmp/mc ${INSECURE_ARG} config host add dest "${ENDPOINT:-https://s3.amazonaws.com}" ACCESS_KEY_ID SECRET_ACCESS_KEY "
    { set +x; } 2>/dev/null
    mc -C /tmp/mc ${INSECURE_ARG} config host add dest "${ENDPOINT:-https://s3.amazonaws.com}" "$ACCESS_KEY_ID" "$SECRET_ACCESS_KEY"
    set -x
}

function clean_backup_s3() {
    mc_add_bucket_dest

    is_object_exist "$S3_BUCKET" "$S3_BUCKET_PATH.$SST_INFO_NAME" || xbcloud delete ${CURL_RET_ERRORS_ARG} ${INSECURE_ARG} --storage=s3 --s3-bucket="$S3_BUCKET" "$S3_BUCKET_PATH.$SST_INFO_NAME"
    is_object_exist "$S3_BUCKET" "$S3_BUCKET_PATH" || xbcloud delete ${CURL_RET_ERRORS_ARG} ${INSECURE_ARG} --storage=s3 --s3-bucket="$S3_BUCKET" "$S3_BUCKET_PATH"
}
