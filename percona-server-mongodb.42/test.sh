#!/bin/bash
set -Eeuo pipefail

declare -a mongodHackedArgs
# _mongod_hack_ensure_arg '--some-arg' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_arg() {
	local ensureArg="$1"; shift
	mongodHackedArgs=( "$@" )
	if ! _mongod_hack_have_arg "$ensureArg" "$@"; then
		mongodHackedArgs+=( "$ensureArg" )
	fi
}

_mongod_hack_have_arg() {
	local checkArg="$1"; shift
	local arg
	for arg; do
		case "$arg" in
			"$checkArg"|"$checkArg"=*)
				return 0
				;;
		esac
	done
	return 1
}

# _mongod_hack_ensure_no_arg '--some-unwanted-arg' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_no_arg() {
	local ensureNoArg="$1"; shift
	mongodHackedArgs=()
	while [ "$#" -gt 0 ]; do
		local arg="$1"; shift
		if [ "$arg" = "$ensureNoArg" ]; then
			continue
		fi
		mongodHackedArgs+=( "$arg" )
	done
}
# _mongod_hack_ensure_no_arg '--some-unwanted-arg' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_no_arg_val() {
	local ensureNoArg="$1"; shift
	mongodHackedArgs=()
	while [ "$#" -gt 0 ]; do
		local arg="$1"; shift
		case "$arg" in
			"$ensureNoArg")
				shift # also skip the value
				continue
				;;
			"$ensureNoArg"=*)
				# value is already included
				continue
				;;
		esac
		mongodHackedArgs+=( "$arg" )
	done
}
# _mongod_hack_rename_arg_save_val '--arg-to-rename' '--arg-to-rename-to' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_rename_arg_save_val() {
    local oldArg="$1"; shift
	local newArg="$1"; shift
    if ! _mongod_hack_have_arg "$oldArg" "$@"; then
		return 0
	fi
    local val="";
	mongodHackedArgs=()
	while [ "$#" -gt 0 ]; do
		local arg="$1"; shift
		if [ "$arg" = "$oldArg" ]; then
                val="$1"
                shift
				continue
		fi
		mongodHackedArgs+=( "$arg" )
	done
    mongodHackedArgs+=( "$newArg" )
    mongodHackedArgs+=( "$val" )
}
# _mongod_hack_ensure_arg_val '--some-arg' 'some-val' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_arg_val() {
	local ensureArg="$1"; shift
	local ensureVal="$1"; shift
	_mongod_hack_ensure_no_arg_val "$ensureArg" "$@"
	mongodHackedArgs+=( "$ensureArg" "$ensureVal" )
}

mongodHackedArgs=( "$@" )

if  _mongod_hack_have_arg "--sslMode" "${mongodHackedArgs[@]}"; then
    tlsVal="disabled"
    if _mongod_hack_have_arg "allowSSL" "${mongodHackedArgs[@]}s"; then
        tlsVal="allowTLS"
    fi
    if _mongod_hack_have_arg "preferSSL" "${mongodHackedArgs[@]}"; then
        tlsVal="preferTLS"
    fi
    if _mongod_hack_have_arg "requireSSL" "${mongodHackedArgs[@]}"; then
        tlsVal="requireTLS"
    fi
    _mongod_hack_ensure_no_arg_val "--sslMode" "$@"
    _mongod_hack_ensure_arg_val --tlsMode "$tlsVal" "${mongodHackedArgs[@]}"
fi

_mongod_hack_rename_arg_save_val "--sslPEMKeyFile" "--tlsCertificateKeyFile" "${mongodHackedArgs[@]}"
_mongod_hack_rename_arg_save_val "--sslPEMKeyPassword" "--tlsCertificateKeyFilePassword" "${mongodHackedArgs[@]}"
_mongod_hack_rename_arg_save_val "--sslClusterFile" "--tlsClusterFile" "${mongodHackedArgs[@]}"
_mongod_hack_rename_arg_save_val "--sslCertificateSelector" "--tlsCertificateSelector" "${mongodHackedArgs[@]}"
_mongod_hack_rename_arg_save_val "--sslClusterCertificateSelector" "--tlsClusterCertificateSelector" "${mongodHackedArgs[@]}"
_mongod_hack_rename_arg_save_val "--sslCAFile" "--tlsCAFile" "${mongodHackedArgs[@]}"
_mongod_hack_rename_arg_save_val "--sslClusterCAFile" "--tlsClusterCAFile" "${mongodHackedArgs[@]}"
_mongod_hack_rename_arg_save_val "--sslCRLFile" "--tlsCRLFile" "${mongodHackedArgs[@]}"
_mongod_hack_rename_arg_save_val "--sslAllowInvalidCertificates" "--tlsAllowInvalidCertificates" "${mongodHackedArgs[@]}"
_mongod_hack_rename_arg_save_val "--sslAllowInvalidHostnames" "--tlsAllowInvalidHostnames" "${mongodHackedArgs[@]}"
_mongod_hack_rename_arg_save_val "--sslAllowConnectionsWithoutCertificates" "--tlsAllowConnectionsWithoutCertificates" "${mongodHackedArgs[@]}"
_mongod_hack_rename_arg_save_val "--sslDisabledProtocols" "--tlsDisabledProtocols" "${mongodHackedArgs[@]}"
_mongod_hack_rename_arg_save_val "--sslFIPSMode" "--tlsFIPSMode" "${mongodHackedArgs[@]}"

printf "result is: \n"
printf '%s ' "${mongodHackedArgs[@]}"
