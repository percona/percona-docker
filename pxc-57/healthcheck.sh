#!/bin/bash
set -eo pipefail

if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
	echo >&2 'healthcheck error: cannot determine  root password!'
	exit 0
fi

# it uses this env variable automatically without specifing -p $MYSQL_ROOT_PASSWORD
export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"

args=(
	# force mysql to not use the local "mysqld.sock" (test "external" connectivity)
	-h"$(hostname --ip-address || echo '127.0.0.1')"
	-u"root"
	-srN
)

if status="$(mysql "${args[@]}" -e "SHOW GLOBAL STATUS LIKE 'wsrep_ready';" | awk '{ print $2; }')" && [ "$status" = 'ON' ]; then
    exit 0
fi
exit 1