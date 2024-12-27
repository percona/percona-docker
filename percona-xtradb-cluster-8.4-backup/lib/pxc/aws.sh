#!/bin/bash

set -o errexit

export AWS_SHARED_CREDENTIALS_FILE='/tmp/aws-credfile'
export AWS_ENDPOINT_URL="${ENDPOINT:-https://s3.amazonaws.com}"
export AWS_REGION="${DEFAULT_REGION:-us-west-2}"

if [ -n "$VERIFY_TLS" ] && [[ $VERIFY_TLS == "false" ]]; then
	AWS_S3_NO_VERIFY_SSL='--no-verify-ssl'
fi

is_object_exist() {
	local bucket="$1"
	local object="$2"

	aws $AWS_S3_NO_VERIFY_SSL s3api head-object  --bucket $bucket --key "$object" || NOT_EXIST=true
	if [[ -z "$NOT_EXIST" ]]; then
		return 1
	fi
}

s3_add_bucket_dest() {
	{ set +x; } 2>/dev/null
	aws configure set aws_access_key_id "$ACCESS_KEY_ID"
	aws configure set aws_secret_access_key "$SECRET_ACCESS_KEY"
	set -x
}

