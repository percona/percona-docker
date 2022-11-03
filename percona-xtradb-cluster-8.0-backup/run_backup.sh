#!/bin/bash

set -o errexit
set -o xtrace
set -m

LIB_PATH='/usr/lib/pxc'
. ${LIB_PATH}/vault.sh
. ${LIB_PATH}/backup.sh

SOCAT_OPTS="TCP-LISTEN:4444,reuseaddr,retry=30"

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
function handle_sigterm() {
	if ((FIRST_RECEIVED == 0)); then
		pid_s=$(ps -C socat -o pid= || true)
		if [ -n "${pid_s}" ]; then
			log 'ERROR' 'SST request failed'
			SST_FAILED=1
			kill $pid_s
			exit 1
		else
			log 'INFO' 'SST request was finished'
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

	log 'INFO' "Backup to $BACKUP_DIR was started"

	socat -u "$SOCAT_OPTS" stdio | xbstream -x &
	wait $!

	log 'INFO' 'Socat was started'

	FIRST_RECEIVED=1
	if [[ $? -ne 0 ]]; then
		log 'ERROR' 'Socat(1) failed'
		log 'ERROR' 'Backup was finished unsuccessfully'
		exit 1
	fi
	echo "[IINFO] Socat(1) returned $?"
	vault_store $BACKUP_DIR/${SST_INFO_NAME}

	if ((SST_FAILED == 0)); then
		FIRST_RECEIVED=0
		socat -u "$SOCAT_OPTS" stdio >xtrabackup.stream
		FIRST_RECEIVED=1
		if [[ $? -ne 0 ]]; then
			log 'ERROR' 'Socat(2) failed'
			log 'ERROR' 'Backup was finished unsuccessfully'
			exit 1
		fi
		log 'INFO' "Socat(2) returned $?"
	fi

	stat xtrabackup.stream
	if (($(stat -c%s xtrabackup.stream) < 5000000)); then
		log 'ERROR' 'Backup is empty'
		log 'ERROR' 'Backup was finished unsuccessfully'
		exit 1
	fi
	md5sum xtrabackup.stream | tee md5sum.txt
}

function backup_s3() {
	mc_add_bucket_dest

	socat -u "$SOCAT_OPTS" stdio | xbstream -x -C /tmp &
	wait $!
	log 'INFO' 'Socat was started'

	FIRST_RECEIVED=1
	if [[ $? -ne 0 ]]; then
		log 'ERROR' 'Socat(1) failed'
		log 'ERROR' 'Backup was finished unsuccessfully'
		exit 1
	fi
	vault_store /tmp/${SST_INFO_NAME}

	xbstream -C /tmp -c ${SST_INFO_NAME} \
		| xbcloud put ${CURL_RET_ERRORS_ARG} ${INSECURE_ARG} --storage=s3 --parallel=10 --md5 --s3-bucket="$S3_BUCKET" "$S3_BUCKET_PATH.$SST_INFO_NAME" 2>&1 \
		| (grep -v "error: http request failed: Couldn't resolve host name" || exit 1)

	if ((SST_FAILED == 0)); then
		FIRST_RECEIVED=0
		socat -u "$SOCAT_OPTS" stdio \
			| xbcloud put ${CURL_RET_ERRORS_ARG} ${INSECURE_ARG} --storage=s3 --parallel=10 --md5 --s3-bucket="$S3_BUCKET" "$S3_BUCKET_PATH" 2>&1 \
			| (grep -v "error: http request failed: Couldn't resolve host name" || exit 1)
		FIRST_RECEIVED=1
	fi

	mc -C /tmp/mc stat ${INSECURE_ARG} "dest/$S3_BUCKET/$S3_BUCKET_PATH.md5"
	md5_size=$(mc -C /tmp/mc stat ${INSECURE_ARG} --json "dest/$S3_BUCKET/$S3_BUCKET_PATH.md5" | sed -e 's/.*"size":\([0-9]*\).*/\1/')
	if [[ $md5_size =~ "Object does not exist" ]] || ((md5_size < 23000)); then
		log 'ERROR' 'Backup is empty'
		log 'ERROR' 'Backup was finished unsuccessfull'
		exit 1
	fi
}

azure_auth_header_file() {
	hex_tmp=$(mktemp)
	signature_tmp=$(mktemp)
	auth_header_tmp=$(mktemp)

	params="$1"
	request_date="$2"

	echo -n "$AZURE_ACCESS_KEY" | base64 -d -w0 | hexdump -ve '1/1 "%02x"' >"$hex_tmp"
	headers="x-ms-date:$request_date\nx-ms-version:2021-06-08"
	resource="/$AZURE_STORAGE_ACCOUNT/$AZURE_CONTAINER_NAME"
	string_to_sign="GET\n\n\n\n\n\n\n\n\n\n\n\n${headers}\n${resource}\n${params}"
	printf '%s' "$string_to_sign" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$(cat "$hex_tmp")" -binary | base64 -w0 >"$signature_tmp"
	echo -n "Authorization: SharedKey $AZURE_STORAGE_ACCOUNT:$(cat "$signature_tmp")" >"$auth_header_tmp"
	echo "$auth_header_tmp"
}

is_object_exist_azure() {
	object="$1"
	connection_string="$ENDPOINT/$AZURE_CONTAINER_NAME?comp=list&restype=container"
	request_date=$(LC_ALL=en_US.utf8 TZ=GMT date "+%a, %d %h %Y %H:%M:%S %Z")
	header_version="x-ms-version: 2021-06-08"
	header_date="x-ms-date: $request_date"
	header_auth_file=$(azure_auth_header_file "comp:list\nrestype:container" "$request_date")

	res=$(curl -s -H "$header_version" -H "$header_date" -H "@$header_auth_file" ${connection_string} | grep $object)

	if [[ ${#res} -ne 0 ]]; then
		return 1
	fi
}

function backup_azure() {
	S3_BUCKET_PATH=${S3_BUCKET_PATH:-$PXC_SERVICE-$(date +%F-%H-%M)-xtrabackup.stream}
	CURL_RET_ERRORS_ARG='--curl-retriable-errors=7'
	ENDPOINT=${AZURE_ENDPOINT:-"https://$AZURE_STORAGE_ACCOUNT.blob.core.windows.net"}

	log 'INFO' "Backup to $ENDPOINT/$AZURE_CONTAINER_NAME/$BACKUP_PATH"

	is_object_exist_azure "$BACKUP_PATH.$SST_INFO_NAME/" || xbcloud delete ${CURL_RET_ERRORS_ARG} ${INSECURE_ARG} --storage=azure "$BACKUP_PATH.$SST_INFO_NAME"
	is_object_exist_azure "$BACKUP_PATH/" || xbcloud delete ${CURL_RET_ERRORS_ARG} ${INSECURE_ARG} --storage=azure "$BACKUP_PATH"

	socat -u "$SOCAT_OPTS" stdio | xbstream -x -C /tmp &
	wait $!
	log 'INFO' 'Socat was started'

	FIRST_RECEIVED=1
	if [[ $? -ne 0 ]]; then
		log 'ERROR' 'Socat(1) failed'
		log 'ERROR' 'Backup was finished unsuccessfully'
		exit 1
	fi
	vault_store /tmp/${SST_INFO_NAME}

	xbstream -C /tmp -c ${SST_INFO_NAME} \
		| xbcloud put ${CURL_RET_ERRORS_ARG} ${INSECURE_ARG} --storage=azure --parallel=10 "$BACKUP_PATH.$SST_INFO_NAME" 2>&1 \
		| (grep -v "error: http request failed: Couldn't resolve host name" || exit 1)

	if ((SST_FAILED == 0)); then
		FIRST_RECEIVED=0
		socat -u "$SOCAT_OPTS" stdio \
			| xbcloud put ${CURL_RET_ERRORS_ARG} ${INSECURE_ARG} --storage=azure --parallel=10 "$BACKUP_PATH" 2>&1 \
			| (grep -v "error: http request failed: Couldn't resolve host name" || exit 1)
		FIRST_RECEIVED=1
	fi
}

check_ssl

trap 'handle_sigterm' 15

if [ -n "$S3_BUCKET" ]; then
	backup_s3
elif [ -n "$AZURE_CONTAINER_NAME" ]; then
	backup_azure
else
	backup_volume
fi

if ((SST_FAILED == 0)); then
	touch /tmp/backup-is-completed
fi
exit $SST_FAILED
