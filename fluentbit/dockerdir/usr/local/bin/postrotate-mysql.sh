#!/bin/bash

set -o errexit

PXC_SERVER_PORT='3306'
MONITOR_USER='monitor'
TIMEOUT=10
MYSQL_CMDLINE="/usr/bin/timeout $TIMEOUT /usr/bin/mysql -nNE -u$MONITOR_USER -h127.0.0.1 -P$PXC_SERVER_PORT"

export MYSQL_PWD=${MONITOR_PASSWORD}

# Check if the audit plugin is loaded
audit_plugin_loaded=$($MYSQL_CMDLINE -e "SHOW PLUGINS" | grep -c 'audit_log' || true)
if [ $audit_plugin_loaded -gt 0 ]; then
    $MYSQL_CMDLINE -e 'FLUSH ERROR LOGS;SET GLOBAL audit_log_flush=1;'
else
    $MYSQL_CMDLINE -e 'FLUSH ERROR LOGS;'
fi
