#!/bin/bash

#set +xe

# use the current scrip name while putting log
script_name=${0##*/}
#script_name="configure-proxysql.sh"

function timestamp() {
  date +"%Y/%m/%d %T"
}

function log() {
  local log_type="$1"
  local msg="$2"
  echo "$(timestamp) [$script_name] [$log_type] $msg"
}

log "" "From $script_name"

# Configs
opt=" -vvv -f "
default_hostgroup_id="10"
reader_hostgroup_id="20"
TIMEOUT="10" # 10 sec timeout to wait for server

# Functions

function mysql_exec() {
  local user="$1"
  local pass="$2"
  local server="$3"
  local port="$4"
  local query="$5"
  local exec_opt="$6"
  mysql $exec_opt --user=${user} --password=${pass} --host=${server} -P${port} -NBe "${query}"
}

function wait_for_mysql() {
    local user="$1"
    local pass="$2"
    local server="$3"
    local port="$4"

    log "INFO" "Waiting for host $server to be online..."
    for i in {900..0}; do
      out=$(mysql_exec ${user} ${pass} ${server} ${port} "select 1;")
      if [[ "$out" == "1" ]]; then
        break
      fi

      log "WARNING" "out is ---'$out'--- MySQL is not up yet... sleeping ..."
      sleep 1
    done

    if [[ "$i" == "0" ]]; then
      log "ERROR" "Server ${server} start failed..."
      exit 1
    fi
}

IFS=',' read -ra BACKEND_SERVERS <<<"$PEERS"

if [[ "${#BACKEND_SERVERS[@]}" -eq 0 ]]; then
  log "ERROR" "Backend pxc servers not found. Exiting ..."
  exit 1
fi

log "INFO" "Provided peers are ${BACKEND_SERVERS[*]}"

# Command $(hostname -I) returns a space separated IP list. We need only the first one.
myips=$(hostname -I)
ipaddr=${myips%% *}
first_host=${BACKEND_SERVERS[0]}

wait_for_mysql \
    root \
    $MYSQL_ROOT_PASSWORD \
    $first_host \
    3306
mysql_exec \
    root \
    $MYSQL_ROOT_PASSWORD \
    $first_host \
    3306 \
    "GRANT ALL ON *.* TO '$MYSQL_PROXY_USER'@'$ipaddr' IDENTIFIED BY '$MYSQL_PROXY_PASSWORD';" \
    $opt

# Now prepare sql for proxysql
# Here, we configure read and write access for two host groups with id 10 and 20.
# Host group 10 is for requests filtered by the pattern '^SELECT.*FOR UPDATE$'
#   and contains only first host from the peers list
# Host group 20 is for requests filtered by the pattern '^SELECT'
#   and contains all of the hosts from the peers list

servers_sql="REPLACE INTO mysql_servers (hostgroup_id, hostname, port) VALUES ($default_hostgroup_id, '$first_host', 3306);"

for server in "${BACKEND_SERVERS[@]}"; do
  echo "Found host: $i"
  wait_for_mysql \
    root \
    $MYSQL_ROOT_PASSWORD \
    $server \
    3306
  servers_sql="$servers_sql\nREPLACE INTO mysql_servers (hostgroup_id, hostname, port) VALUES ($reader_hostgroup_id, '$server', 3306);"
done

servers_sql="$servers_sql\nLOAD MYSQL SERVERS TO RUNTIME; SAVE MYSQL SERVERS TO DISK;"

users_sql="
REPLACE INTO mysql_users (username, password, active, default_hostgroup, max_connections) VALUES ('root', '$MYSQL_ROOT_PASSWORD', 1, $default_hostgroup_id, 200);
REPLACE INTO mysql_users (username, password, active, default_hostgroup, max_connections) VALUES ('$MYSQL_PROXY_USER', '$MYSQL_PROXY_PASSWORD', 1, $default_hostgroup_id, 200);
LOAD MYSQL USERS TO RUNTIME; SAVE MYSQL USERS TO DISK;
"

scheduler_sql="
UPDATE global_variables SET variable_value='$MYSQL_PROXY_USER' WHERE variable_name='mysql-monitor_username';
UPDATE global_variables SET variable_value='$MYSQL_PROXY_PASSWORD' WHERE variable_name='mysql-monitor_password';
LOAD MYSQL VARIABLES TO RUNTIME;SAVE MYSQL VARIABLES TO DISK;
REPLACE INTO scheduler(id,active,interval_ms,filename,arg1,arg2,arg3,arg4,arg5) VALUES (1,'1','3000','/usr/share/proxysql/tools/proxysql_galera_checker.sh','10','20','1','1', '/var/lib/proxysql/proxysql_galera_checker.log');
LOAD SCHEDULER TO RUNTIME; SAVE SCHEDULER TO DISK;
"

rw_split_sql="
UPDATE mysql_users SET default_hostgroup=$default_hostgroup_id;
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;
REPLACE INTO mysql_query_rules (rule_id,active,match_digest,destination_hostgroup,apply)
VALUES
(1,1,'^SELECT.*FOR UPDATE$',10,1),
(2,1,'^SELECT',20,1);
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
"

log "INFO" "sql query to configure proxysql

$servers_sql

$users_sql

$scheduler_sql

$rw_split_sql"

# wait for proxysql process to be run
wait_for_mysql admin admin 127.0.0.1 6032

mysql_exec \
    admin \
    admin \
    127.0.0.1 \
    6032 \
    "$cleanup_sql $servers_sql $users_sql $scheduler_sql $rw_split_sql" \
    $opt

log "INFO" "All done!"
