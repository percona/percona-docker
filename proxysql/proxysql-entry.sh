#!/bin/bash
if [ -z "$CLUSTER_NAME" ]; then
        echo >&2 'Error:  You need to specify CLUSTER_NAME'
        exit 1
fi

if [ -z "$DISCOVERY_SERVICE" ]; then
        echo >&2 'Error:  You need to specify DISCOVERY_SERVICE'
        exit 1
fi

/usr/bin/proxysql --initial -f -c /etc/proxysql.cnf 
