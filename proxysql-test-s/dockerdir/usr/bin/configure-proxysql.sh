#!/bin/bash

#set +xe

echo "++++++++++++ i'm in configure-proxysql.sh"

# Configs
opt=" -vvv -f "
default_hostgroup_id="10"
reader_hostgroup_id="20"
TIMEOUT="10" # 10 sec timeout to wait for server

# Functions

function mysql_root_exec() {
  local server="$1"
  local query="$2"
  printf "%s\n" \
    "[client]" \
    "user=root" \
    "password=${MYSQL_ROOT_PASSWORD}" \
    "host=${server}" |
    timeout $TIMEOUT $remote mysql --defaults-file=/dev/stdin --protocol=tcp -s -NB -e "${query}"
}

function wait_for_mysql() {
  #  local host=$1
  #  echo "Waiting for host $h to be online..."
  #  for i in {900..0}; do
  #    out=$(mysqladmin -u root --password=${MYSQL_ROOT_PASSWORD} --host=${host} ping 2>/dev/null)
  #    if [[ "$out" == "mysqld is alive" ]]; then
  #      break
  #    fi
  #
  #    echo -n .
  #    sleep 1
  #  done
  #
  #  if [[ "$i" == "0" ]]; then
  #    echo ""
  #    echo "====== [ERROR] ======" "Server ${host} start failed..."
  #    exit 1
  #  fi

  local h=$1
  echo "Waiting for host $h to be online..."
      while [ "$(mysql_root_exec $h 'select 1')" != "1" ]; do
#  while true; do
#    for i in {900..0}; do
#      out=$(mysqladmin -u root --password=${MYSQL_ROOT_PASSWORD} --host=${host} ping 2>/dev/null)
#      if [[ "$out" == "mysqld is alive" ]]; then
#        break
#      fi
#
#      echo -n .
#      sleep 1
#    done
#
#    if [[ "$i" == "0" ]]; then
#      echo ""
#      echo "====== [ERROR] ======" "Server ${host} start failed..."
#      exit 1
#    fi

    echo "MySQL is not up yet... sleeping ..."
    sleep 1
  done
}

#while read -ra LINE; do
#  PEERS=("${PEERS[@]}" $LINE)
#done

IFS=',' read -ra PEERS <<<"$HOSTS"
echo "+++++++++++++++++"

if [[ "${#PEERS[@]}" -eq 0 ]]; then
  echo "========= [ERROR] ========= backend pxc servers not found"
  exit 1
fi

echo "=========== [INFO] ============= peers are ${PEERS[*]}"

# Command $(hostname -I) returns a space separated IP list. We need only the first one.
myips=$(hostname -I)
ipaddr=${myips%% *}
first_host=${PEERS[0]}

wait_for_mysql $first_host
mysql $opt -h $first_host -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON *.* TO '$MYSQL_PROXY_USER'@'$ipaddr' IDENTIFIED BY '$MYSQL_PROXY_PASSWORD';"

# Now prepare sql for proxysql

servers_sql="REPLACE INTO mysql_servers (hostgroup_id, hostname, port) VALUES ($default_hostgroup_id, '$first_host', 3306);"

for i in "${PEERS[@]}"; do
  echo "Found host: $i"
  wait_for_mysql $i
  servers_sql="$servers_sql\nREPLACE INTO mysql_servers (hostgroup_id, hostname, port) VALUES ($reader_hostgroup_id, '$i', 3306);"
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
REPLACE INTO scheduler(id,active,interval_ms,filename,arg1,arg2,arg3,arg4,arg5) VALUES (1,'1','3000','/usr/bin/proxysql_galera_checker','10','20','1','1', '/var/lib/proxysql/proxysql_galera_checker.log');
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

echo ""
echo "========= [INFO] ========= sql query to configure proxysql

$servers_sql

$users_sql

$scheduler_sql

$rw_split_sql"
sleep 30
#wait_for_mysql 127.0.0.1
#$remote mysql $opt -h 127.0.0.1 -P6032 -uadmin -padmin -e "$cleanup_sql $servers_sql $users_sql $scheduler_sql $rw_split_sql"
mysql -uadmin -padmin -h127.0.0.1 -P6032 -e "$cleanup_sql $servers_sql $users_sql $scheduler_sql $rw_split_sql"

echo "All done!"
