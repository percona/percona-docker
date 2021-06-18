#!/bin/bash

PXC_SERVER_IP=$3

PXC_SERVER_PORT='3306'
path_to_haproxy_cfg='/etc/haproxy/pxc'
if [ -f "$path_to_haproxy_cfg/PROXY_PROTOCOL_ENABLED" ]; then
    PXC_SERVER_PORT='33062'
fi

MONITOR_USER='monitor'
TIMEOUT=10
MYSQL_CMDLINE="/usr/bin/timeout $TIMEOUT /usr/bin/mysql -nNE -u$MONITOR_USER"

AVAILABLE_NODES=1
if [ -f "$path_to_haproxy_cfg/AVAILABLE_NODES" ]; then
    AVAILABLE_NODES=$(/bin/cat $path_to_haproxy_cfg/AVAILABLE_NODES)
fi

MONITOR_PASSWORD=${MONITOR_PASSWORD:-$PATH}
PXC_NODE_STATUS=($(MYSQL_PWD="${MONITOR_PASSWORD}" $MYSQL_CMDLINE -h $PXC_SERVER_IP -P $PXC_SERVER_PORT \
        -e "SHOW STATUS LIKE 'wsrep_local_state';SHOW VARIABLES LIKE 'pxc_maint_mode';SHOW GLOBAL STATUS LIKE 'wsrep_cluster_status';" \
        | /usr/bin/grep -A 1 -E 'wsrep_local_state$|pxc_maint_mode$|wsrep_cluster_status$' | /usr/bin/sed -n -e '2p' -e '5p' -e '8p' | /usr/bin/tr '\n' ' '))

# ${PXC_NODE_STATUS[0]} - wsrep_local_state
# ${PXC_NODE_STATUS[1]} - pxc_maint_mod
# ${PXC_NODE_STATUS[2]} - wsrep_cluster_status
echo "The following values are used for PXC node $PXC_SERVER_IP in backend $HAPROXY_PROXY_NAME:"
echo "wsrep_local_state is ${PXC_NODE_STATUS[0]}; pxc_maint_mod is ${PXC_NODE_STATUS[1]}; wsrep_cluster_status is ${PXC_NODE_STATUS[2]}; $AVAILABLE_NODES nodes are available"
if [[ ${PXC_NODE_STATUS[2]} == 'Primary' &&  ( ${PXC_NODE_STATUS[0]} -eq 4 || \
    ${PXC_NODE_STATUS[0]} -eq 2 && "${AVAILABLE_NODES}" -le 1 ) \
    && ${PXC_NODE_STATUS[1]} == 'DISABLED' ]];
then
    echo "PXC node $PXC_SERVER_IP for backend $HAPROXY_PROXY_NAME is ok"
    exit 0
else
    echo "PXC node $PXC_SERVER_IP for backend $HAPROXY_PROXY_NAME is not ok"
    exit 1
fi
