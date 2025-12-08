#!/bin/bash
set -e

has_source_flag=false
has_target_flag=false

for arg in "$@"; do
	case "$arg" in
		--source|--source=*)
			has_source_flag=true
			;;
		--target|--target=*)
			has_target_flag=true
			;;
	esac
done

args=()
if [ "$has_source_flag" = false ] || [ "$has_target_flag" = false ]; then
	if [ -n "${PCSM_SOURCE_URI:-}" ] && [ "$has_source_flag" = false ]; then
		args+=(--source="$PCSM_SOURCE_URI")
	fi
	if [ -n "${PCSM_TARGET_URI:-}" ] && [ "$has_target_flag" = false ]; then
		args+=(--target="$PCSM_TARGET_URI")
	fi
fi

has_source=false
if [ "$has_source_flag" = true ]; then
	has_source=true
elif [ -n "${PCSM_SOURCE_URI:-}" ]; then
	has_source=true
fi

has_target=false
if [ "$has_target_flag" = true ]; then
	has_target=true
elif [ -n "${PCSM_TARGET_URI:-}" ]; then
	has_target=true
fi

if [ "$#" -eq 0 ] || [ "${1:0:1}" = '-' ] || [ "$1" = "pcsm" ]; then
	if [ "$has_source" = false ] || [ "$has_target" = false ]; then
		echo >&2 "ERROR: Both source and target MongoDB URIs should be provided"
		echo >&2 "  Use --source and --target flags or"
		echo >&2 "  Set PCSM_SOURCE_URI and PCSM_TARGET_URI environment variables"
		exit 1
	fi
fi

# If command starts with an option, prepend pcsm
if [ "$#" -eq 0 ] || [ "${1:0:1}" = '-' ]; then
	# Prepend pcsm and add any environment variable arguments
	set -- pcsm "${args[@]}" "$@"
elif [ "$1" = "pcsm" ]; then
	# pcsm is already the first argument, insert env var args after it
	set -- pcsm "${args[@]}" "${@:2}"
else
	# Custom command, don't modify
	set -- "$@"
fi

exec "$@"