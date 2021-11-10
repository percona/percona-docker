#!/bin/bash

set -e

ORC_HOST=127.0.0.1:3000

wait_for_leader() {
    local retry=0
    local leader=""

    until [[ ${leader} != "" ]]; do
        if [ ${retry} -gt 60 ]; then
            echo '[WARNING] Waiting for leader. Will fail after 60 attempts'
            exit 1
        fi

        local leader=$(curl "${ORC_HOST}/api/raft-leader" 2>/dev/null)

        retry=$(($retry + 1))
        sleep 1
    done
}

am_i_leader() {
    local http_code=$(curl -w httpcode=%{http_code} "${ORC_HOST}/api/leader-check" 2>/dev/null | sed -e 's/.*\httpcode=//')

    if [ ${http_code} -ne 200 ]; then
        return 1
    fi

    echo '[INFO] I am a leader'
    return 0
}

discover() {
    local host=$1
    local port=$2

    HOSTNAME=$(curl -s "${ORC_HOST}/api/instance/${host}/${port}" | jq '.InstanceAlias' | tr -d 'null')
    if [ -n "$HOSTNAME" ]; then
        echo "[INFO] The Mysql node ${host} is already present in orchestrator. Skipping ..."
        return 0
    fi

    for i in {1..5}; do
        R_CODE=$(curl -s "${ORC_HOST}/api/discover/${host}/${port}" | jq '.Code' | tr -d '"')
        if [ "$R_CODE" == 'ERROR' ]; then
            echo "[ERROR] Mysql node ${host} can't be discovered"
            sleep 1
            continue
        else
            echo "[INFO] Mysql node ${host} was discovered"
            break
        fi
   done
}

main() {
    # Wait for the leader election
    wait_for_leader

    # Exit if not master
    while ! am_i_leader; do
        echo '[INFO] I am not a leader. Sleeping ...'

        sleep 1
        exit 0
    done

    # Discover
    while read mysql_host; do
        if [ -z "$mysql_host" ]; then
            echo '[INFO] Could not find PEERS ...'
            exit 0
        fi

        discover "${mysql_host}" 3306
    done
}

main
