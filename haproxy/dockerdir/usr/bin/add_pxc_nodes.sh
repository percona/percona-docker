#!/bin/bash

set -o errexit
set -o xtrace

function main() {
    echo "Running $0"

    NODE_LIST=()
    NODE_LIST_REPL=()
    NODE_LIST_ADMIN=()
    NODE_LIST_BACKUP=()
    firs_node=''
    firs_node_admin=''
    main_node=''

    send_proxy=''
    if [[ "${IS_PROXY_PROTOCOL}" = "yes" ]]; then
        send_proxy='send-proxy-v2'
    fi
    while read pxc_host; do
        if [ -z "$pxc_host" ]; then
            echo "Could not find PEERS ..."
            exit 0
        fi

        node_name=$(echo "$pxc_host" | cut -d . -f -1)
        node_id=$(echo $node_name |  awk -F'-' '{print $NF}')
        NODE_LIST_REPL+=( "server $node_name $pxc_host:3306 $send_proxy check inter 10000 rise 1 fall 2 weight 1" )
        if [ "x$node_id" == 'x0' ]; then
            main_node="$pxc_host"
            firs_node="server $node_name $pxc_host:3306 $send_proxy check inter 10000 rise 1 fall 2 weight 1 on-marked-up shutdown-backup-sessions"
            firs_node_admin="server $node_name $pxc_host:33062 check inter 10000 rise 1 fall 2 weight 1 on-marked-up shutdown-backup-sessions"
            continue
        fi
        NODE_LIST_BACKUP+=("galera-nodes/$node_name" "galera-admin-nodes/$node_name")
        NODE_LIST+=( "server $node_name $pxc_host:3306 $send_proxy check inter 10000 rise 1 fall 2 weight 1 backup" )
        NODE_LIST_ADMIN+=( "server $node_name $pxc_host:33062 check inter 10000 rise 1 fall 2 weight 1 backup" )
    done

    NODE_LIST=( "$firs_node" "$(printf '%s\n' "${NODE_LIST[@]}" | sort --version-sort -r | uniq)" )
    NODE_LIST_ADMIN=( "$firs_node_admin" "$(printf '%s\n' "${NODE_LIST_ADMIN[@]}" | sort --version-sort -r | uniq)" )

path_to_haproxy_cfg='/etc/haproxy/pxc'
cat <<-EOF > "$path_to_haproxy_cfg/haproxy.cfg"
    backend galera-nodes
      mode tcp
      option srvtcpka
      balance roundrobin
      option external-check
      external-check path "$MONITOR_PASSWORD"
      external-check command /usr/local/bin/check_pxc.sh
EOF

    echo "${#NODE_LIST[@]}" > $path_to_haproxy_cfg/AVAILABLE_NODES
    ( IFS=$'\n'; echo "${NODE_LIST[*]}" ) >> "$path_to_haproxy_cfg/haproxy.cfg"

cat <<-EOF >> "$path_to_haproxy_cfg/haproxy.cfg"
    backend galera-admin-nodes
      mode tcp
      option srvtcpka
      balance roundrobin
      option external-check
      external-check path "$MONITOR_PASSWORD"
      external-check command /usr/local/bin/check_pxc.sh
EOF

    ( IFS=$'\n'; echo "${NODE_LIST_ADMIN[*]}" ) >> "$path_to_haproxy_cfg/haproxy.cfg"

cat <<-EOF >> "$path_to_haproxy_cfg/haproxy.cfg"
    backend galera-replica-nodes
      mode tcp
      option srvtcpka
      balance roundrobin
      option external-check
      external-check path "$MONITOR_PASSWORD"
      external-check command /usr/local/bin/check_pxc.sh
EOF
    ( IFS=$'\n'; echo "${NODE_LIST_REPL[*]}" ) >> "$path_to_haproxy_cfg/haproxy.cfg"

    SOCKET='/etc/haproxy/pxc/haproxy.sock'
    path_to_custom_global_cnf='/etc/haproxy-custom'
    if [ -f "$path_to_custom_global_cnf/haproxy-global.cfg" ]; then
        SOCKET_CUSTOM=$(grep 'stats socket' "$path_to_custom_global_cnf/haproxy-global.cfg" | awk '{print $3}')
        if [ -S "$SOCKET_CUSTOM" ]; then
            SOCKET="$SOCKET_CUSTOM"
        fi
        haproxy -c -f "$path_to_custom_global_cnf/haproxy-global.cfg" -f $path_to_haproxy_cfg/haproxy.cfg
    else
        haproxy -c -f /etc/haproxy/haproxy-global.cfg -f $path_to_haproxy_cfg/haproxy.cfg
    fi

    if [ -n "$main_node" ]; then
         if /usr/local/bin/check_pxc.sh '' '' "$main_node"; then
             for backup_server in ${NODE_LIST_BACKUP[@]}; do
                 echo "shutdown sessions server $backup_server" | socat stdio "${SOCKET}"
             done
         fi
    fi

    if [ -f "$path_to_haproxy_cfg/haproxy.pid" ]; then
        kill -SIGUSR2 $(cat /etc/haproxy/pxc/haproxy.pid)
    fi
}

main
exit 0
