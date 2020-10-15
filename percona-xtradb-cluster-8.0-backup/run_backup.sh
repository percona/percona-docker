#!/bin/bash

set -o errexit
set -o xtrace

LIB_PATH='/usr/lib/pxc'
. ${LIB_PATH}/vault.sh

SOCAT_OPTS="TCP-LISTEN:4444,reuseaddr,retry=30"
SST_INFO_NAME=sst_info

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
        SOCAT_OPTS="openssl-listen:4444,reuseaddr,cert=${CERT},key=${KEY},cafile=${CA},verify=1,retry=30"
    fi
}

FIRST_RECEIVED=0
SST_FAILED=0
function handle_sigint() {
    if (( $FIRST_RECEIVED == 0 )); then
        pid_s=$(ps -C socat -o pid= || true)
        if [ -n "${pid_s}" ]; then
            echo "SST request failed"
            SST_FAILED=1
            kill $pid_s
            exit 1
        else
            echo "SST request was finished"
        fi
    fi
}

function backup_volume() {
    BACKUP_DIR=${BACKUP_DIR:-/backup/$PXC_SERVICE-$(date +%F-%H-%M)}

    if [ -d "$BACKUP_DIR" ]; then   
        rm -rf $BACKUP_DIR/{xtrabackup.*,sst_info}
    fi

    mkdir -p "$BACKUP_DIR"
    cd "$BACKUP_DIR" || exit

    echo "Backup to $BACKUP_DIR was started"

    socat -u "$SOCAT_OPTS" stdio | xbstream -x &
    wait $!

    echo "Socat was started"

    FIRST_RECEIVED=1
    if [[ $? -ne 0 ]]; then
        echo "socat(1) failed"
        exit 1
    fi
    echo "socat(1) returned $?"
    vault_store $BACKUP_DIR/${SST_INFO_NAME}

    if (( $SST_FAILED == 0 )); then
        FIRST_RECEIVED=0
        socat -u "$SOCAT_OPTS" stdio >xtrabackup.stream
        FIRST_RECEIVED=1
        if [[ $? -ne 0 ]]; then
            echo "socat(2) failed"
            exit 1
        fi
        echo "socat(2) returned $?"
    fi

    echo "Backup finished"

    stat xtrabackup.stream
    if (($(stat -c%s xtrabackup.stream) < 5000000)); then
        echo empty backup
        exit 1
    fi
    md5sum xtrabackup.stream | tee md5sum.txt
}

function backup_s3() {
    S3_BUCKET_PATH=${S3_BUCKET_PATH:-$PXC_SERVICE-$(date +%F-%H-%M)-xtrabackup.stream}

    echo "Backup to s3://$S3_BUCKET/$S3_BUCKET_PATH started"
    { set +x; } 2>/dev/null
    echo "+ mc -C /tmp/mc config host add dest "${ENDPOINT:-https://s3.amazonaws.com}" ACCESS_KEY_ID SECRET_ACCESS_KEY"
    mc -C /tmp/mc config host add dest "${ENDPOINT:-https://s3.amazonaws.com}" "$ACCESS_KEY_ID" "$SECRET_ACCESS_KEY"
    set -x

    xbcloud delete --storage=s3 --s3-bucket="$S3_BUCKET" "$S3_BUCKET_PATH.$SST_INFO_NAME" || :
    xbcloud delete --storage=s3 --s3-bucket="$S3_BUCKET" "$S3_BUCKET_PATH" || :

    socat -u "$SOCAT_OPTS" stdio | xbstream -x -C /tmp &
    wait $!
    echo "Socat was started"

    FIRST_RECEIVED=1
    if [[ $? -ne 0 ]]; then
        echo "socat(1) failed"
        exit 1
    fi
    vault_store /tmp/${SST_INFO_NAME}

    xbstream -C /tmp -c ${SST_INFO_NAME} \
        | xbcloud put --storage=s3 --parallel=10 --md5 --s3-bucket="$S3_BUCKET" "$S3_BUCKET_PATH.$SST_INFO_NAME" 2>&1 \
        | (grep -v "error: http request failed: Couldn't resolve host name" || exit 1)

    if (( $SST_FAILED == 0 )); then
         FIRST_RECEIVED=0
         socat -u "$SOCAT_OPTS" stdio  \
            | xbcloud put --storage=s3 --parallel=10 --md5 --s3-bucket="$S3_BUCKET" "$S3_BUCKET_PATH" 2>&1 \
            | (grep -v "error: http request failed: Couldn't resolve host name" || exit 1)
         FIRST_RECEIVED=1
         echo "Backup finished"
    fi

    mc -C /tmp/mc stat "dest/$S3_BUCKET/$S3_BUCKET_PATH.md5"
    md5_size=$(mc -C /tmp/mc stat --json "dest/$S3_BUCKET/$S3_BUCKET_PATH.md5" | sed -e 's/.*"size":\([0-9]*\).*/\1/')
    if [[ $md5_size =~ "Object does not exist" ]] || (($md5_size < 23000)); then
        echo empty backup
         exit 1
    fi
}

check_ssl

trap 'handle_sigint' 2

if [ -n "$S3_BUCKET" ]; then
    backup_s3
else
    backup_volume
fi

exit $SST_FAILED
