#!/bin/bash

set -e
set -o xtrace

ORC_HOST=127.0.0.1:3000

wait_for_leader() {
    local retry=0
    local leader=""

    until [[ ${leader} != "" ]]; do
        if [ ${retry} -gt 60 ]; then
            echo "Waiting for leader failed after 60 attempts"
            exit 1
        fi

        local leader=$(curl "${ORC_HOST}/api/raft-leader" 2>/dev/null)

        retry=$(($retry + 1))
        sleep 1
    done
}

function mysql_exec() {
    local server="$1"
    local port="$2"
    local query="$3"

    { set +x; } 2>/dev/null
    ORC_PASSWORD=$(/bin/cat /etc/orchestrator/orchestrator-users-secret/orchestrator)
    MYSQL_PWD="${ORC_PASSWORD}" timeout 600 mysql -h "${server}" -P ${port} -uorchestrator -s -NB -e "${query}"
    set -x
}

function wait_for_mysql() {
    local host="$1"
    local port=$2

    echo "Waiting for host $host to be online..."
    while [ "$(mysql_exec "$host" "$port" 'select 1')" != "1" ]; do
        echo "MySQL is not up yet... sleeping ..."
        sleep 1
    done
}

am_i_leader() {
    local http_code=$(curl -w httpcode=%{http_code} "${ORC_HOST}/api/leader-check" 2>/dev/null | sed -e 's/.*\httpcode=//')

    if [ ${http_code} -ne 200 ]; then
        return 1
    fi

    return 0
}

discover() {
    local host=$1
    local port=$2

    curl "${ORC_HOST}/api/discover/${host}/${port}"
}

main() {
    # Wait for the leader election
    wait_for_leader

    # Exit if not master
    if ! am_i_leader; then
        echo "I'm not the leader. Exiting..."
        exit 0
    fi

    # Discover
    while read mysql_host; do
        if [ -z "$mysql_host" ]; then
            echo "Could not find PEERS ..."
            exit 0
        fi

        wait_for_mysql "${mysql_host}" 3306
        discover "${mysql_host}" 3306
    done
}

main
