#!/bin/bash

set -o xtrace

PXC_SERVER_IP=$3
PXC_SERVER_PORT=$4
MONITOR_USER='monitor'
TIMEOUT=10
MONITOR_PASSWORD="$PATH"

MYSQL_CMDLINE="/usr/bin/timeout $TIMEOUT /usr/bin/mysql -nNE -u$MONITOR_USER"

AVAILABLE_NODES=1
if [ -f '/etc/haproxy/pxc/AVAILABLE_NODES' ]; then
    AVAILABLE_NODES=$(/bin/cat /etc/haproxy/pxc/AVAILABLE_NODES)
fi

PXC_NODE_STATUS=($(MYSQL_PWD="${MONITOR_PASSWORD}" $MYSQL_CMDLINE -h $PXC_SERVER_IP -P $PXC_SERVER_PORT \
        -e "SHOW STATUS LIKE 'wsrep_local_state';SHOW VARIABLES LIKE 'pxc_maint_mode';SHOW GLOBAL STATUS LIKE 'wsrep_cluster_status';" \
        | /usr/bin/grep -A 1 -E 'wsrep_local_state$|pxc_maint_mode$|wsrep_cluster_status$' | /usr/bin/sed -n -e '2p' -e '5p' -e '8p' | /usr/bin/tr '\n' ' '))

# ${PXC_NODE_STATUS[0]} - wsrep_local_state
# ${PXC_NODE_STATUS[1]} - pxc_maint_mod
# ${PXC_NODE_STATUS[2]} - wsrep_cluster_status
if [[ ${PXC_NODE_STATUS[2]} == 'Primary' &&  ( ${PXC_NODE_STATUS[0]} -eq 4 || \
    ${PXC_NODE_STATUS[0]} -eq 2 && "${AVAILABLE_NODES}" -le 1 ) \
    && ${PXC_NODE_STATUS[1]} == 'DISABLED' ]];
then
    echo "PXC node $PXC_SERVER_IP is ok"
    exit 0
else
    echo "PXC node $PXC_SERVER_IP is not ok"
    exit 1
fi
