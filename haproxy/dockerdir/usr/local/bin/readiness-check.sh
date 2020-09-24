#!/bin/bash

set -o xtrace

PXC_SERVER_PORT='33062'
MONITOR_USER='monitor'
TIMEOUT=10
MYSQL_CMDLINE="/usr/bin/timeout $TIMEOUT /usr/bin/mysql -nNE -u$MONITOR_USER"

{ set +x; } 2>/dev/null
MONITOR_PASSWORD=${MONITOR_PASSWORD:-$PATH}
STATUS=$(MYSQL_PWD="${MONITOR_PASSWORD}" $MYSQL_CMDLINE -h127.0.0.1 -P$PXC_SERVER_PORT -e 'select 1;' | sed -n -e '2p' | tr '\n' ' ')
set -x

if [[ "${STATUS}" -eq 1 ]]; then
    exit 0
fi

exit 1
