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
		--directory ${ROUTER_DIR}

	sed -i 's/logging_folder=.*/logging_folder=/g' ${ROUTER_DIR}/mysqlrouter.conf
	sed -i "/\[logger\]/a destination=/dev/stdout" ${ROUTER_DIR}/mysqlrouter.conf
fi

if [ "$1" = 'mysqlrouter' ]; then
    if [[ -z $MYSQL_HOST || -z $MYSQL_PORT || -z $MYSQL_USER || -z $MYSQL_PASSWORD ]]; then
            echo "We require all of"
            echo "    MYSQL_HOST"
            echo "    MYSQL_PORT"
            echo "    MYSQL_USER"
            echo "    MYSQL_PASSWORD"
            echo "to be set. Exiting."
            exit 1
    fi

    PASSFILE=$(mktemp)
    echo "$MYSQL_PASSWORD" > "$PASSFILE"
    DEFAULTS_EXTRA_FILE=$(mktemp)
    cat >"$DEFAULTS_EXTRA_FILE" <<EOF
[client]
password="$MYSQL_PASSWORD"
EOF
    max_tries=12
    attempt_num=0
    until (echo > "/dev/tcp/$MYSQL_HOST/$MYSQL_PORT") >/dev/null 2>&1; do
      echo "Waiting for mysql server $MYSQL_HOST ($attempt_num/$max_tries)"
      sleep $(( attempt_num++ ))
      if (( attempt_num == max_tries )); then
        exit 1
      fi
    done
    echo "Succesfully contacted mysql server at $MYSQL_HOST. Checking for cluster state."
    mysqlrouter --bootstrap "$MYSQL_USER@$MYSQL_HOST:$MYSQL_PORT"  --directory /tmp/mysqlrouter --force < "$PASSFILE"
    sed -i -e 's/logging_folder=.*$/logging_folder=/' /tmp/mysqlrouter/mysqlrouter.conf
    echo "Starting mysql-router."
    exec "$@" --config /tmp/mysqlrouter/mysqlrouter.conf
fi

rm -f "$PASSFILE"
rm -f "$DEFAULTS_EXTRA_FILE"
unset DEFAULTS_EXTRA_FILE
exec "$@"
