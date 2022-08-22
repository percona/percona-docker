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
		--conf-set-option=http_server.bind_address=0.0.0.0 \
		--directory ${ROUTER_DIR}

	sed -i 's/logging_folder=.*/logging_folder=/g' ${ROUTER_DIR}/mysqlrouter.conf
	sed -i "/\[logger\]/a destination=/dev/stdout" ${ROUTER_DIR}/mysqlrouter.conf
fi

exec "$@"
