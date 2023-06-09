#!/bin/bash

set -o errexit

PXC_SERVER_PORT='3306'
MONITOR_USER='monitor'
TIMEOUT=10
MYSQL_CMDLINE="/usr/bin/timeout $TIMEOUT /usr/bin/mysql -nNE -u$MONITOR_USER"

export MYSQL_PWD=${MONITOR_PASSWORD}
$MYSQL_CMDLINE -h127.0.0.1 -P$PXC_SERVER_PORT -e 'FLUSH ERROR LOGS;set global audit_log_flush=1;'
