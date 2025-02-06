#!/bin/bash

set -o errexit

LIB_PATH='/usr/lib/pxc'
. ${LIB_PATH}/aws.sh

SST_INFO_NAME=sst_info
XBCLOUD_ARGS="--curl-retriable-errors=7 $XBCLOUD_EXTRA_ARGS"
INSECURE_ARG=""

if [ -n "$VERIFY_TLS" ] && [[ $VERIFY_TLS == "false" ]]; then
	XBCLOUD_ARGS="--insecure ${XBCLOUD_ARGS}"
fi

S3_BUCKET_PATH=${S3_BUCKET_PATH:-$PXC_SERVICE-$(date +%F-%H-%M)-xtrabackup.stream}
BACKUP_PATH=${BACKUP_PATH:-$PXC_SERVICE-$(date +%F-%H-%M)-xtrabackup.stream}

log() {
	{ set +x; } 2>/dev/null
	local level=$1
	local message=$2
	local now=$(date '+%F %H:%M:%S')

	echo "${now} [${level}] ${message}"
	set -x
}

clean_backup_s3() {
	s3_add_bucket_dest

	# The existing backup must be deleted before creating a new one.
	# xbcloud does not support overwriting backups and will fail with an error:
	# https://github.com/percona/percona-xtrabackup/blob/a99dce574690616b296b8a8cc7c590deb937f7d3/storage/innobase/xtrabackup/src/xbcloud/xbcloud.cc#L956
	is_object_exist "$S3_BUCKET" "$S3_BUCKET_PATH.$SST_INFO_NAME" || xbcloud delete ${XBCLOUD_ARGS} --storage=s3 --s3-bucket="$S3_BUCKET" "$S3_BUCKET_PATH.$SST_INFO_NAME"
	is_object_exist "$S3_BUCKET" "$S3_BUCKET_PATH/" || xbcloud delete ${XBCLOUD_ARGS} --storage=s3 --s3-bucket="$S3_BUCKET" "$S3_BUCKET_PATH"
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

	res=$(curl -s -H "$header_version" -H "$header_date" -H "@$header_auth_file" "${connection_string}" | grep "$object")
	set -x

	if [[ ${#res} -ne 0 ]]; then
		return 1
	fi
}
