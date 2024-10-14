#!/bin/bash

set -o errexit
set -o xtrace
set -m

LIB_PATH='/usr/lib/pxc'
. ${LIB_PATH}/vault.sh
. ${LIB_PATH}/backup.sh
. ${LIB_PATH}/aws.sh

handle_sigterm() {
    log 'INFO' 'Post recv script was finished'
    exit 0
}

backup_volume() {
        log 'INFO' 'Checking backup in PVC'
        cd "$BACKUP_DIR"

        stat xtrabackup.stream
        if (($(stat -c%s xtrabackup.stream) < 5000000)); then
                log 'ERROR' 'Backup is empty'
                log 'ERROR' 'Backup was finished unsuccessfully'
                exit 1
        fi
        md5sum xtrabackup.stream | tee md5sum.txt
}

backup_s3() {
        log 'INFO' 'Checking backup in S3'
        aws $AWS_S3_NO_VERIFY_SSL s3 ls s3://$S3_BUCKET/$S3_BUCKET_PATH.md5
        md5_size=$(aws $AWS_S3_NO_VERIFY_SSL --output json s3api list-objects --bucket "$S3_BUCKET" --prefix "$S3_BUCKET_PATH.md5" --query 'Contents[0].Size' | sed -e 's/.*"size":\([0-9]*\).*/\1/')
        if [[ $md5_size =~ "Object does not exist" ]] || ((md5_size < 23000)) ; then
            log 'ERROR' 'Backup is empty'
            log 'ERROR' 'Backup was finished unsuccessfull'
            exit 1
        fi
}

backup_azure() {
        log 'INFO' 'Checking backup in Azure'
}

trap 'handle_sigterm' 15

if [ -n "$S3_BUCKET" ]; then
        backup_s3
elif [ -n "$AZURE_CONTAINER_NAME" ]; then
        backup_azure
else
        backup_volume
fi

exit 0
