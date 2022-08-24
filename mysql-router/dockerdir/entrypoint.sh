#!/bin/bash

set -e

if [ -n "$KUBERNETES_SERVICE_HOST" ]; then
	ROUTER_DIR=${ROUTER_DIR:-/tmp/router}
	OPERATOR_USER=${OPERATOR_USER:-operator}
	NAMESPACE=$(</var/run/secrets/kubernetes.io/serviceaccount/namespace)

	if [ -f "/etc/mysql/mysql-users-secret/$OPERATOR_USER" ]; then
		OPERATOR_PASS=$(</etc/mysql/mysql-users-secret/$OPERATOR_USER)
	fi

	mysqlrouter --force \
		--bootstrap ${OPERATOR_USER}:${OPERATOR_PASS}@${MYSQL_SERVICE_NAME}-0.${MYSQL_SERVICE_NAME}.${NAMESPACE}.svc.cluster.local \
		--conf-bind-address 0.0.0.0 \
		--conf-set-option=routing.bind_port=3306 \
		--conf-set-option=routing.bind_address=0.0.0.0 \
		--conf-set-option=routing.routing_strategy=first-available \
		--conf-set-option=routing.destinations=metadata-cache://${MYSQL_SERVICE_NAME%'-mysql'}/?role=PRIMARY \
		--conf-set-option=routing:admin_rw.bind_port=33062 \
		--conf-set-option=routing:admin_rw.bind_address=0.0.0.0 \
		--conf-set-option=routing:admin_rw.routing_strategy=first-available \
		--conf-set-option=routing:admin_rw.destinations=metadata-cache://${MYSQL_SERVICE_NAME%'-mysql'}/?role=PRIMARY \
		--directory ${ROUTER_DIR}

	sed -i 's/logging_folder=.*/logging_folder=/g' ${ROUTER_DIR}/mysqlrouter.conf
	sed -i "/\[logger\]/a destination=/dev/stdout" ${ROUTER_DIR}/mysqlrouter.conf
fi

exec "$@"
