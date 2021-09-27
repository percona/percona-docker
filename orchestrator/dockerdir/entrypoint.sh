#!/bin/sh
set -e
set -o xtrace

export PATH=$PATH:/usr/local/orchestrator

if [ "$1" = 'orchestrator' ]; then
    orchestrator_opt='-config /etc/orchestrator/orchestrator.conf.json http'
fi

if [ -n "$KUBERNETES_SERVICE_HOST" ]; then
    PATH_ORC_CONF_FILE='/etc/orchestrator'
    jq -M ". + {
                HTTPAdvertise:\"http://$HOSTNAME-svc:80\",
                RaftAdvertise:\"$HOSTNAME-svc\",
                RaftBind:\"$HOSTNAME\",
                RaftNodes:[\"$HOSTNAME-svc\"]
          }" "${PATH_ORC_CONF_FILE}/orchestrator.conf.json" 1<>"${PATH_ORC_CONF_FILE}/orchestrator.conf.json"

    { set +x; } 2>/dev/null
    PATH_TO_SECRET='/etc/orchestrator/orchestrator-users-secret'
    if [ -f "$PATH_TO_SECRET/TOPOLOGY_PASSWORD" ]; then
        TOPOLOGY_PASSWORD=$(/bin/cat $PATH_TO_SECRET/TOPOLOGY_PASSWORD)
    fi
    if [ -f "$PATH_TO_SECRET/TOPOLOGY_UASER" ]; then
        TOPOLOGY_USER=$(/bin/cat $PATH_TO_SECRET/TOPOLOGY_USER)
    fi
    sed -r "s|^[#]?user=.*$|user=${TOPOLOGY_USER:-$ORC_TOPOLOGY_USER}|" "${PATH_ORC_CONF_FILE}/orc-topology.cnf" 1<>"${PATH_ORC_CONF_FILE}/orc-topology.cnf"
    sed -r "s|^[#]?password=.*$|password=${TOPOLOGY_PASSWORD-$ORC_TOPOLOGY_PASSWORD}|" "${PATH_ORC_CONF_FILE}/orc-topology.cnf" 1<>"${PATH_ORC_CONF_FILE}/orc-topology.cnf"
    set -x
fi

exec "$@" $orchestrator_opt
