#!/bin/bash

PATRONI_PORT=8008
PATRONI_HOST=localhost

recovery_file='tmp/sleep-forever'
if [ -f "${recovery_file}" ]; then
	set +o xtrace
	echo "The $recovery_file file is detected, node is going to an infinite loop"
	echo "If you want to exit from the infinite loop, remove the $recovery_file file"
	while [ -f "${recovery_file}" ]; do
		sleep 3
	done
	exit 0
fi

response=$(curl -s -o /dev/null -w "%{http_code}" -k "https://${PATRONI_HOST}:${PATRONI_PORT}/readiness")

if [[ "$response" -eq 200 ]]; then
    exit 0
fi
exit 1
