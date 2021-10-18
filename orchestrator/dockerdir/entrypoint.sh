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
                HTTPAdvertise:\"http://$HOSTNAME.$ORC_SERVICE:80\",
                RaftAdvertise:\"$HOSTNAME.$ORC_SERVICE\",
                RaftBind:\"$HOSTNAME.$ORC_SERVICE\",
                MySQLTopologySSLPrivateKeyFile:\"/etc/orchestrator/ssl/tls.key\",
                MySQLTopologySSLCertFile:\"/etc/orchestrator/ssl/tls.crt\",
                MySQLTopologySSLCAFile:\"/etc/orchestrator/ssl/ca.crt\",
                RaftNodes:[\"$HOSTNAME.$ORC_SERVICE\"]
          }" "${PATH_ORC_CONF_FILE}/orchestrator.conf.json" 1<>"${PATH_ORC_CONF_FILE}/orchestrator.conf.json"

    { set +x; } 2>/dev/null
    PATH_TO_SECRET='/etc/orchestrator/orchestrator-users-secret'
    TOPOLOGY_USER=${ORC_TOPOLOGY_USER:-orchestrator}
    if [ -f "$PATH_TO_SECRET/$TOPOLOGY_USER" ]; then
        TOPOLOGY_PASSWORD=$(<$PATH_TO_SECRET/$TOPOLOGY_USER)
    fi
    temp=$(mktemp)
    sed -r "s|^[#]?user=.*$|user=${TOPOLOGY_USER}|" "${PATH_ORC_CONF_FILE}/orc-topology.cnf" > "${temp}"
    sed -r "s|^[#]?password=.*$|password=${TOPOLOGY_PASSWORD:-$ORC_TOPOLOGY_PASSWORD}|" "${PATH_ORC_CONF_FILE}/orc-topology.cnf" > "${temp}"
    cat "${temp}" > "${PATH_ORC_CONF_FILE}/orc-topology.cnf"
    rm "${temp}"
    set -x
fi

exec "$@" $orchestrator_opt
