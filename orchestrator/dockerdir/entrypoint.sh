#!/bin/sh
set -e

export PATH=$PATH:/usr/local/orchestrator

ORC_CONF_PATH=${ORC_CONF_PATH:-/etc/orchestrator}
ORC_CONF_FILE=${ORC_CONF_FILE:-"${ORC_CONF_PATH}/orchestrator.conf.json"}
TOPOLOGY_USER=${ORC_TOPOLOGY_USER:-orchestrator}
CUSTOM_CONF_FILE=${ORC_CONF_PATH}/config/orchestrator.conf.json

if [ -n "$KUBERNETES_SERVICE_HOST" ]; then
	set -o xtrace

	sleep 10 # give time for SRV records to update

	NAMESPACE=$(</var/run/secrets/kubernetes.io/serviceaccount/namespace)
	jq -M ". + {
                HTTPAdvertise:\"http://$HOSTNAME.$NAMESPACE:3000\",
                RaftAdvertise:\"$HOSTNAME.$NAMESPACE\",
                RaftBind:\"$HOSTNAME.$ORC_SERVICE.$NAMESPACE\",
                RaftEnabled: ${RAFT_ENABLED:-"true"},
                MySQLTopologySSLPrivateKeyFile:\"${ORC_CONF_PATH}/ssl/tls.key\",
                MySQLTopologySSLCertFile:\"${ORC_CONF_PATH}/ssl/tls.crt\",
                MySQLTopologySSLCAFile:\"${ORC_CONF_PATH}/ssl/ca.crt\",
                RaftNodes:[]
          }" "${ORC_CONF_FILE}" 1<>"${ORC_CONF_FILE}"

	if [ -f ${CUSTOM_CONF_FILE} ]; then
		jq -M -s ".[0] * .[1]" "${ORC_CONF_FILE}" "${CUSTOM_CONF_FILE}" 1<>"${ORC_CONF_FILE}"
	fi

	{ set +x; } 2>/dev/null
	PATH_TO_SECRET="${ORC_CONF_PATH}/orchestrator-users-secret"
	if [ -f "$PATH_TO_SECRET/$TOPOLOGY_USER" ]; then
		TOPOLOGY_PASSWORD=$(<$PATH_TO_SECRET/$TOPOLOGY_USER)
	fi
fi

if [ ! -d "/var/lib/orchestrator" ]; then
	mkdir /var/lib/orchestrator
fi

if [ "$1" = 'orchestrator' ]; then
	orchestrator_opt="-config ${ORC_CONF_FILE} http"
fi

set +o xtrace
temp=$(mktemp)
sed -r "s|^[#]?user=.*$|user=${TOPOLOGY_USER}|" "${ORC_CONF_PATH}/orc-topology.cnf" >"${temp}"
sed -r "s|^[#]?password=.*$|password=${TOPOLOGY_PASSWORD:-$ORC_TOPOLOGY_PASSWORD}|" "${ORC_CONF_PATH}/orc-topology.cnf" >"${temp}"
cat "${temp}" >"${ORC_CONF_PATH}/orc-topology.cnf"
rm "${temp}"
set -o xtrace

exec "$@" $orchestrator_opt
