#!/bin/bash
#
# Script to make a proxy (ie HAProxy) capable of monitoring Percona XtraDB Cluster nodes properly
#
# Authors:
# Raghavendra Prabhu <raghavendra.prabhu@percona.com>
# Olaf van Zandwijk <olaf.vanzandwijk@nedap.com>
#
# Based on the original script from Unai Rodriguez and Olaf (https://github.com/olafz/percona-clustercheck)
#
# Grant privileges required:
# GRANT PROCESS ON *.* TO 'clustercheck'@'localhost' IDENTIFIED BY 'clustercheckpassword!';
# Changed by Alexander Rubin to fix the Openshift/Kubernetes issue where we can't pass env parameters to liveness probes

if [[ $1 == '-h' || $1 == '--help' ]];then
    echo "Usage: $0 <user> <pass> <available_when_donor=0|1> <log_file> <available_when_readonly=0|1> <defaults_extra_file>"
    exit
fi

# if the disabled file is present, return error. This allows
# admins to manually remove a node from a cluster easily.
if [ -e "/var/tmp/clustercheck.disabled" ]; then
    exit 1
fi

set -e

if [ -f /etc/sysconfig/clustercheck ]; then
        . /etc/sysconfig/clustercheck
fi

if [ -f /var/lib/mysql/sst_in_progress ]; then
    exit 0
fi

MYSQL_USERNAME="${MYSQL_USERNAME:-clustercheck}"
MYSQL_PASSWORD="${CLUSTERCHECK_PASSWORD:-clustercheckpassword!}"
AVAILABLE_WHEN_DONOR=${AVAILABLE_WHEN_DONOR:-1}
ERR_FILE="${ERR_FILE:-/var/log/mysql/clustercheck.log}"
AVAILABLE_WHEN_READONLY=${AVAILABLE_WHEN_READONLY:-1}
DEFAULTS_EXTRA_FILE=${DEFAULTS_EXTRA_FILE:-/etc/my.cnf}

#Timeout exists for instances where mysqld may be hung
TIMEOUT=10

EXTRA_ARGS=""
if [[ -n "$MYSQL_USERNAME" ]]; then
    EXTRA_ARGS="$EXTRA_ARGS --user=${MYSQL_USERNAME}"
fi
if [[ -r $DEFAULTS_EXTRA_FILE ]];then
    MYSQL_CMDLINE="mysql --defaults-extra-file=$DEFAULTS_EXTRA_FILE -nNE --connect-timeout=$TIMEOUT \
                    ${EXTRA_ARGS}"
else
    MYSQL_CMDLINE="mysql -nNE --connect-timeout=$TIMEOUT ${EXTRA_ARGS}"
fi
#
# Perform the query to check the wsrep_local_state
#
WSREP_STATUS=($(MYSQL_PWD="${MYSQL_PASSWORD}" $MYSQL_CMDLINE -e "SHOW GLOBAL STATUS LIKE 'wsrep_%';"  \
    2>${ERR_FILE} | grep -A 1 -E 'wsrep_local_state$|wsrep_cluster_status$' \
    | sed -n -e '2p'  -e '5p' | tr '\n' ' '))

if [[ ${WSREP_STATUS[1]} == 'Primary' && ( ${WSREP_STATUS[0]} -eq 4 || \
    ( ${WSREP_STATUS[0]} -eq 2 && $AVAILABLE_WHEN_DONOR -eq 1 ) ) ]]
then
    # Check only when set to 0 to avoid latency in response.
    if [[ $AVAILABLE_WHEN_READONLY -eq 0 ]];then
        READ_ONLY=$($MYSQL_CMDLINE -e "SHOW GLOBAL VARIABLES LIKE 'read_only';" \
                    2>${ERR_FILE} | tail -1 2>>${ERR_FILE})

        if [[ "${READ_ONLY}" == "ON" ]];then
            # Percona XtraDB Cluster node local state is 'Synced', but it is in
            # read-only mode. The variable AVAILABLE_WHEN_READONLY is set to 0.
            # => return HTTP 503
            # Shell return-code is 1
            exit 1
        fi
    fi
    # Percona XtraDB Cluster node local state is 'Synced' => return HTTP 200
    # Shell return-code is 0
    exit 0
else
    # Percona XtraDB Cluster node local state is not 'Synced' => return HTTP 503
    # Shell return-code is 1
    exit 1
fi
