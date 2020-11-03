#!/bin/bash

set -o errexit

PXC_SERVER_PORT='3306'
MONITOR_USER='monitor'
TIMEOUT=10
MYSQL_CMDLINE="/usr/bin/timeout $TIMEOUT /usr/bin/mysql -nNE -u$MONITOR_USER"

export MYSQL_PWD=${MONITOR_PASSWORD}
$MYSQL_CMDLINE -h127.0.0.1 -P$PXC_SERVER_PORT -e 'select @@global.long_query_time into @lqt_save; set global long_query_time=2000; select sleep(2); FLUSH LOGS; select sleep(2); set global long_query_time=@lqt_save;'
