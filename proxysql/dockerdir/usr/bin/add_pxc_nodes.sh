#!/bin/bash

set -o errexit
set -o xtrace

function mysql_root_exec() {
  local server="$1"
  local query="$2"
  set +o xtrace
  MYSQL_PWD="${OPERATOR_PASSWORD:-operator}" timeout 600 mysql -h "${server}" -uoperator -s -NB -e "${query}"
  set -o xtrace
}

function wait_for_mysql() {
    local h="$1"
    echo "Waiting for host $h to be online..."
    while [ "$(mysql_root_exec "$h" 'select 1')" != "1" ]
    do
        echo "MySQL is not up yet... sleeping ..."
        sleep 1
    done
}

function proxysql_admin_exec() {
  local server="$1"
  local query="$2"
  set +o xtrace
  MYSQL_PWD="${PROXY_ADMIN_PASSWORD:-admin}" timeout 600 mysql -h "${server}" -P6032 -u "${PROXY_ADMIN_USER:-admin}" -s -NB -e "${query}"
  set -o xtrace
}

function wait_for_proxy() {
    local h=127.0.0.1
    echo "Waiting for host $h to be online..."
    while [ "$(proxysql_admin_exec "$h" 'select 1')" != "1" ]
    do
        echo "ProxySQL is not up yet... sleeping ..."
        sleep 1
    done
}

function main() {
    echo "Running $0"

    read -ra first_host
    if [ -z "$first_host" ]; then
        echo "Could not find PEERS ..."
        exit
    fi
    pod_zero=$(echo "$first_host" | cut -d . -f 1 | sed -r 's/-[0-9]+$/-0/')
    service=$(echo "$first_host" | cut -d . -f 2-)

    sleep 15s # wait for evs.inactive_timeout
    wait_for_mysql "$service"
    wait_for_proxy

    SSL_ARG=""
    temp=$(mktemp)
    if [ "$(proxysql_admin_exec "127.0.0.1" 'SELECT variable_value FROM global_variables WHERE variable_name="mysql-have_ssl"')" = "true" ]; then
        if [ "${PXC_HANDLER}" == "scheduler" ]; then
            sed "s/^useSSL.*=.*$/useSSL=1/" /etc/config.toml > ${temp} && cp -f ${temp} /etc/config.toml
        else
            SSL_ARG="--use-ssl=yes"
        fi
    fi

    if [ "${PXC_HANDLER}" == "scheduler" ]; then
        sed "s/^clusterHost.*=.*\"$/clusterHost=\"$first_host\"/" /etc/config.toml > ${temp} && cp -f ${temp} /etc/config.toml
        rm ${temp}

        set +o errexit
        if proxysql-admin --config-file=/etc/proxysql-admin.cnf --is-enabled >/dev/null 2>&1; then
            echo "Cleaning setup from proxysql-admin..."
            proxysql-admin --config-file=/etc/proxysql-admin.cnf --disable
        fi
        set -o errexit

        percona-scheduler-admin \
            --config-file=/etc/config.toml \
            --write-node="$pod_zero.$service:3306" \
            --enable \
            --update-cluster \
            --remove-all-servers \
            --disable-updates \
            --force

        percona-scheduler-admin \
            --config-file=/etc/config.toml \
            --write-node="$pod_zero.$service:3306" \
            --sync-multi-cluster-users \
            --add-query-rule \
            --disable-updates \
            --force

        percona-scheduler-admin \
            --config-file=/etc/config.toml \
            --update-mysql-version
    else
        set +o errexit
        if percona-scheduler-admin --config-file=/etc/config.toml --is-enabled >/dev/null 2>&1; then
            echo "Cleaning setup from percona-scheduler-admin..."
            percona-scheduler-admin --config-file=/etc/config.toml --disable
        fi
        set -o errexit

        proxysql-admin \
            --config-file=/etc/proxysql-admin.cnf \
            --cluster-hostname="$first_host" \
            --enable \
            --update-cluster \
            --force \
            --remove-all-servers \
            --disable-updates \
            $SSL_ARG

        proxysql-admin \
            --config-file=/etc/proxysql-admin.cnf \
            --cluster-hostname="$first_host" \
            --sync-multi-cluster-users \
            --add-query-rule \
            --disable-updates \
            --force

        proxysql-admin \
            --config-file=/etc/proxysql-admin.cnf \
            --cluster-hostname="$first_host" \
            --update-mysql-version
    fi

    echo "All done!"
}

main
exit 0
