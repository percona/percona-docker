#!/bin/bash

set -o errexit
set -o xtrace

LIB_PATH='/usr/lib/pxc'
. ${LIB_PATH}/vault.sh

GARBD_OPTS=""
SOCAT_OPTS="TCP-LISTEN:4444,reuseaddr,retry=30"
SST_INFO_NAME=sst_info

INSECURE_ARG=""
if [ -n "$VERIFY_TLS" ] && [[ $VERIFY_TLS == "false" ]]; then
	INSECURE_ARG="--insecure"
fi

get_backup_source() {
	CLUSTER_SIZE=$(peer-list -on-start=/usr/bin/get-pxc-state -service=$PXC_SERVICE 2>&1 \
		| grep wsrep_cluster_size \
		| sort \
		| tail -1 \
		| cut -d : -f 12)

	FIRST_NODE=$(peer-list -on-start=/usr/bin/get-pxc-state -service=$PXC_SERVICE 2>&1 \
		| grep wsrep_ready:ON:wsrep_connected:ON:wsrep_local_state_comment:Synced:wsrep_cluster_status:Primary \
		| sort -r \
		| tail -1 \
		| cut -d : -f 2 \
		| cut -d . -f 1)

	SKIP_FIRST_POD='|'
	if ((${CLUSTER_SIZE:-0} > 1)); then
		SKIP_FIRST_POD="$FIRST_NODE"
	fi
	peer-list -on-start=/usr/bin/get-pxc-state -service=$PXC_SERVICE 2>&1 \
		| grep wsrep_ready:ON:wsrep_connected:ON:wsrep_local_state_comment:Synced:wsrep_cluster_status:Primary \
		| grep -v $SKIP_FIRST_POD \
		| sort \
		| tail -1 \
		| cut -d : -f 2 \
		| cut -d . -f 1
}

check_ssl() {
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
		GARBD_OPTS="socket.ssl_ca=${CA};socket.ssl_cert=${CERT};socket.ssl_key=${KEY};socket.ssl_cipher=;pc.weight=0;${GARBD_OPTS}"
		SOCAT_OPTS="openssl-listen:4444,reuseaddr,cert=${CERT},key=${KEY},cafile=${CA},verify=1,retry=30"
	fi
}

request_streaming() {
	local LOCAL_IP=$(hostname -i | sed -E 's/.*\b([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\b.*/\1/')
	local NODE_NAME=$(get_backup_source)

	if [ -z "$NODE_NAME" ]; then
		peer-list -on-start=/usr/bin/get-pxc-state -service=$PXC_SERVICE
		echo "[ERROR] Cannot find node for backup"
		exit 1
	fi

	timeout -k 25 20 \
		garbd \
		--address "gcomm://$NODE_NAME.$PXC_SERVICE?gmcast.listen_addr=tcp://0.0.0.0:4567" \
		--donor "$NODE_NAME" \
		--group "$PXC_SERVICE" \
		--options "$GARBD_OPTS" \
		--sst "xtrabackup-v2:$LOCAL_IP:4444/xtrabackup_sst//1" \
		2>&1 | tee /tmp/garbd.log

	if grep 'State transfer request failed' /tmp/garbd.log; then
		exit 1
	fi
	if grep 'WARN: Protocol violation. JOIN message sender ... (garb) is not in state transfer' /tmp/garbd.log; then
		exit 1
	fi
	if grep 'WARN: Rejecting JOIN message from ... (garb): new State Transfer required.' /tmp/garbd.log; then
		exit 1
	fi
	if grep 'INFO: Shifting CLOSED -> DESTROYED (TO: -1)' /tmp/garbd.log; then
		exit 1
	fi
	if ! grep 'INFO: Sending state transfer request' /tmp/garbd.log; then
		exit 1
	fi
}

backup_volume() {
	BACKUP_DIR=${BACKUP_DIR:-/backup/$PXC_SERVICE-$(date +%F-%H-%M)}
	mkdir -p "$BACKUP_DIR"
	cd "$BACKUP_DIR" || exit

	echo "[INFO] Backup to $BACKUP_DIR was started"
	request_streaming

	echo '[INFO] Socat was started'

	socat -u "$SOCAT_OPTS" stdio | xbstream -x $XBSTREAM_EXTRA_ARGS
	if [[ $? -ne 0 ]]; then
		echo '[ERROR] Socat(1) failed'
		exit 1
	fi
	echo "[INFO] Socat(1) returned $?"
	vault_store $BACKUP_DIR/${SST_INFO_NAME}

	socat -u "$SOCAT_OPTS" stdio >xtrabackup.stream
	if [[ $? -ne 0 ]]; then
		echo '[ERROR] Socat(2) failed'
		exit 1
	fi
	echo "[INFO] Socat(2) returned $?"

	stat xtrabackup.stream
	if (($(stat -c%s xtrabackup.stream) < 5000000)); then
		echo '[ERROR] Backup was finished unsuccessfully'
		echo '[ERROR] Backup is empty'
		exit 1
	fi
	md5sum xtrabackup.stream | tee md5sum.txt

	echo '[INFO] Backup was finished successfully'
}

is_object_exist() {
	local bucket="$1"
	local object="$2"

	if [[ -n "$(mc -C /tmp/mc ${INSECURE_ARG} --json ls "dest/$bucket/$object" | jq '.status')" ]]; then
		return 1
	fi
}

backup_s3() {
	S3_BUCKET_PATH=${S3_BUCKET_PATH:-$PXC_SERVICE-$(date +%F-%H-%M)-xtrabackup.stream}

	echo "[INFO] Backup to s3://$S3_BUCKET/$S3_BUCKET_PATH started"
	{ set +x; } 2>/dev/null
	echo "+ mc -C /tmp/mc ${INSECURE_ARG} config host add dest "${ENDPOINT:-https://s3.amazonaws.com}" ACCESS_KEY_ID SECRET_ACCESS_KEY"
	mc -C /tmp/mc ${INSECURE_ARG} config host add dest "${ENDPOINT:-https://s3.amazonaws.com}" "$ACCESS_KEY_ID" "$SECRET_ACCESS_KEY"
	set -x
	is_object_exist "$S3_BUCKET" "$S3_BUCKET_PATH.$SST_INFO_NAME" || xbcloud delete ${INSECURE_ARG} $XBCLOUD_EXTRA_ARGS --storage=s3 --s3-bucket="$S3_BUCKET" "$S3_BUCKET_PATH.$SST_INFO_NAME"
	is_object_exist "$S3_BUCKET" "$S3_BUCKET_PATH" || xbcloud delete ${INSECURE_ARG} $XBCLOUD_EXTRA_ARGS --storage=s3 --s3-bucket="$S3_BUCKET" "$S3_BUCKET_PATH"
	request_streaming

	socat -u "$SOCAT_OPTS" stdio | xbstream -x -C /tmp $XBSTREAM_EXTRA_ARGS
	if [[ $? -ne 0 ]]; then
		echo '[ERROR] Socat(1) failed'
		exit 1
	fi
	vault_store /tmp/${SST_INFO_NAME}
	xbstream -C /tmp -c ${SST_INFO_NAME} $XBSTREAM_EXTRA_ARGS \
		| xbcloud put --storage=s3 --parallel="$(grep -c processor /proc/cpuinfo)" --md5 ${INSECURE_ARG} $XBCLOUD_EXTRA_ARGS --s3-bucket="$S3_BUCKET" "$S3_BUCKET_PATH.$SST_INFO_NAME" 2>&1 \
		| (grep -v "error: http request failed: Couldn't resolve host name" || exit 1)

	socat -u "$SOCAT_OPTS" stdio \
		| xbcloud put --storage=s3 --parallel="$(grep -c processor /proc/cpuinfo)" --md5 ${INSECURE_ARG} $XBCLOUD_EXTRA_ARGS --s3-bucket="$S3_BUCKET" "$S3_BUCKET_PATH" 2>&1 \
		| (grep -v "error: http request failed: Couldn't resolve host name" || exit 1)

	mc -C /tmp/mc ${INSECURE_ARG} stat "dest/$S3_BUCKET/$S3_BUCKET_PATH.md5"
	md5_size=$(mc -C /tmp/mc ${INSECURE_ARG} stat --json "dest/$S3_BUCKET/$S3_BUCKET_PATH.md5" | sed -e 's/.*"size":\([0-9]*\).*/\1/')
	if [[ $md5_size =~ "Object does not exist" ]] || ((md5_size < 23000)); then
		echo '[ERROR] Backup is empty'
		echo '[ERROR] Backup was finished unsuccessfully'
		exit 1
	fi
	echo '[INFO] Backup was finished successfully'
}

azure_auth_header_file() {
	hex_tmp=$(mktemp)
	signature_tmp=$(mktemp)
	auth_header_tmp=$(mktemp)

	params="$1"
	request_date="$2"

	{ set +x; } 2>/dev/null
	echo -n "$AZURE_ACCESS_KEY" | base64 -d -w0 | hexdump -ve '1/1 "%02x"' >"$hex_tmp"
	headers="x-ms-date:$request_date\nx-ms-version:2021-06-08"
	resource="/$AZURE_STORAGE_ACCOUNT/$AZURE_CONTAINER_NAME"
	string_to_sign="GET\n\n\n\n\n\n\n\n\n\n\n\n${headers}\n${resource}\n${params}"
	printf '%s' "$string_to_sign" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$(cat "$hex_tmp")" -binary | base64 -w0 >"$signature_tmp"
	echo -n "Authorization: SharedKey $AZURE_STORAGE_ACCOUNT:$(cat "$signature_tmp")" >"$auth_header_tmp"
	set -x
	echo "$auth_header_tmp"
}

is_object_exist_azure() {
	object="$1"
	{ set +x; } 2>/dev/null
	connection_string="$ENDPOINT/$AZURE_CONTAINER_NAME?comp=list&restype=container"
	request_date=$(LC_ALL=en_US.utf8 TZ=GMT date "+%a, %d %h %Y %H:%M:%S %Z")
	header_version="x-ms-version: 2021-06-08"
	header_date="x-ms-date: $request_date"
	header_auth_file=$(azure_auth_header_file "comp:list\nrestype:container" "$request_date")

	res=$(curl -s -H "$header_version" -H "$header_date" -H "@$header_auth_file" ${connection_string} | grep $object)
	set -x

	if [[ ${#res} -ne 0 ]]; then
		return 1
	fi
}

backup_azure() {
	BACKUP_PATH=${BACKUP_PATH:-$PXC_SERVICE-$(date +%F-%H-%M)-xtrabackup.stream}
	ENDPOINT=${AZURE_ENDPOINT:-"https://$AZURE_STORAGE_ACCOUNT.blob.core.windows.net"}

	echo "[INFO] Backup to $ENDPOINT/$AZURE_CONTAINER_NAME/$BACKUP_PATH"

	is_object_exist_azure "$BACKUP_PATH.$SST_INFO_NAME/" || xbcloud delete ${INSECURE_ARG} $XBCLOUD_EXTRA_ARGS --storage=azure "$BACKUP_PATH.$SST_INFO_NAME"
	is_object_exist_azure "$BACKUP_PATH/" || xbcloud delete ${INSECURE_ARG} $XBCLOUD_EXTRA_ARGS --storage=azure "$BACKUP_PATH"
	request_streaming

	socat -u "$SOCAT_OPTS" stdio | xbstream -x -C /tmp $XBSTREAM_EXTRA_ARGS
	if [[ $? -ne 0 ]]; then
		echo '[ERROR] Socat(1) failed'
		exit 1
	fi
	vault_store /tmp/${SST_INFO_NAME}

	xbstream -C /tmp -c ${SST_INFO_NAME} $XBSTREAM_EXTRA_ARGS \
		| xbcloud put ${INSECURE_ARG} --storage=azure --parallel="$(grep -c processor /proc/cpuinfo)" $XBCLOUD_EXTRA_ARGS "$BACKUP_PATH.$SST_INFO_NAME" 2>&1 \
		| (grep -v "error: http request failed: Couldn't resolve host name" || exit 1)

	socat -u "$SOCAT_OPTS" stdio \
		| xbcloud put ${INSECURE_ARG} --storage=azure --parallel="$(grep -c processor /proc/cpuinfo)" $XBCLOUD_EXTRA_ARGS "$BACKUP_PATH" 2>&1 \
		| (grep -v "error: http request failed: Couldn't resolve host name" || exit 1)
	echo '[INFO] Backup was finished successfully'
}

check_ssl
if [ -n "$S3_BUCKET" ]; then
	backup_s3
elif [ -n "$AZURE_CONTAINER_NAME" ]; then
	backup_azure
else
	backup_volume
fi
