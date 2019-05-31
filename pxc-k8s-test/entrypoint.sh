#!/bin/bash
set -xe

USER_ID=$(id -u)

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
  CMDARG="$@"
fi

if [ -z "$CLUSTER_NAME" ]; then
  echo >&2 'Error:  You need to specify CLUSTER_NAME'
  exit 1
fi

if [ -z "$POD_NAMESPACE" ]; then
  echo >&2 'Error:  You need to specify POD_NAMESPACE'
  exit 1
else
  # Is running in Kubernetes, so find all other pods
  # belonging to the namespace
  echo "Percona XtraDB Cluster: Finding peers"
  # K8S_SVC_NAME=$(hostname -f | cut -d"." -f2)
  echo "Using service name: ${GOV_SVC}"
  /usr/bin/peer-finder -on-start="/usr/bin/configure-pxc.sh" -service=${GOV_SVC}
fi

# Get config
DATADIR="$("mysqld" --verbose --wsrep_provider= --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"

# if we have CLUSTER_JOIN - then we do not need to perform datadir initialize
# the data will be copied from another node
cat /etc/mysql/conf.d/node.cnf
WSREP_CLUSTER_ADDRESS=$(grep wsrep_cluster_address /etc/mysql/conf.d/node.cnf | sed -e 's^.*gcomm://^^')
echo "Cluster address set to: $WSREP_CLUSTER_ADDRESS"

if [ -z "$WSREP_CLUSTER_ADDRESS" ]; then

  echo "Cluster address is empty! "

  if [ ! -e "$DATADIR/mysql" ]; then
    if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" -a -z "$MYSQL_ROOT_PASSWORD_FILE" ]; then
      echo >&2 'error: database is uninitialized and password option is not specified '
      echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ROOT_PASSWORD_FILE,  MYSQL_ALLOW_EMPTY_PASSWORD or MYSQL_RANDOM_ROOT_PASSWORD'
      exit 1
    fi

    if [ ! -z "$MYSQL_ROOT_PASSWORD_FILE" -a -z "$MYSQL_ROOT_PASSWORD" ]; then
      MYSQL_ROOT_PASSWORD=$(cat $MYSQL_ROOT_PASSWORD_FILE)
    fi
    rm -rf $DATADIR/* && mkdir -p $DATADIR

    echo "Running --initialize-insecure on $DATADIR"
    ls -lah $DATADIR
    mysqld --initialize-insecure --skip-ssl
    echo 'Finished --initialize-insecure'

    mysqld --user=mysql --datadir="$DATADIR" --skip-networking &
    pid="$!"

    mysql=(mysql --protocol=socket -uroot)

    for i in {30..0}; do
      if echo 'SELECT 1' | "${mysql[@]}" &>/dev/null; then
        break
      fi
      echo 'MySQL init process in progress...'
      sleep 1
    done
    if [ "$i" = 0 ]; then
      echo >&2 'MySQL init process failed.'
      exit 1
    fi

    # sed is for https://bugs.mysql.com/bug.php?id=20545
    mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/FCTY/' | "${mysql[@]}" mysql
    if [ ! -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
      MYSQL_ROOT_PASSWORD="$(pwmake 128)"
      echo "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
    fi
    # The 'username'@‘localhost' account can be used only when connecting from the
    # local host.
    # The 'username'@'%' account uses the '%' wildcard for the host part, so it
    # can be used to connect from any host.
    "${mysql[@]}" <<-EOSQL
                    -- What's done in this file shouldn't be replicated
                    --  or products like mysql-fabric won't work
                    SET @@SESSION.SQL_LOG_BIN=0;
                    CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
                    GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
                    ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
                    CREATE USER 'xtrabackup'@'localhost' IDENTIFIED BY '$XTRABACKUP_PASSWORD';
                    GRANT RELOAD,PROCESS,LOCK TABLES,REPLICATION CLIENT ON *.* TO 'xtrabackup'@'localhost';
                    GRANT REPLICATION CLIENT ON *.* TO monitor@'%' IDENTIFIED BY 'monitor';
                    GRANT PROCESS ON *.* TO monitor@localhost IDENTIFIED BY 'monitor';
                    DROP DATABASE IF EXISTS test ;
                    FLUSH PRIVILEGES ;
EOSQL
#                    GRANT SELECT, PROCESS, SUPER, REPLICATION CLIENT, RELOAD ON *.* TO 'monitor'@'localhost' IDENTIFIED BY '$MONITOR_PASSWORD';
#                    GRANT SELECT, UPDATE, DELETE, DROP ON performance_schema.* TO 'monitor'@'localhost';

    if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
      mysql+=(-p"${MYSQL_ROOT_PASSWORD}")
    fi

    if [ "$MYSQL_DATABASE" ]; then
      echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | "${mysql[@]}"
      mysql+=("$MYSQL_DATABASE")
    fi

    if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
      echo "CREATE USER '"$MYSQL_USER"'@'%' IDENTIFIED BY '"$MYSQL_PASSWORD"' ;" | "${mysql[@]}"

      if [ "$MYSQL_DATABASE" ]; then
        echo "GRANT ALL ON \`"$MYSQL_DATABASE"\`.* TO '"$MYSQL_USER"'@'%' ;" | "${mysql[@]}"
      fi

      echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
    fi

    if [ ! -z "$MYSQL_ONETIME_PASSWORD" ]; then
      "${mysql[@]}" <<-EOSQL
                        ALTER USER 'root'@'%' PASSWORD EXPIRE;
EOSQL
    fi
    if ! kill -s TERM "$pid" || ! wait "$pid"; then
      echo >&2 'MySQL init process failed.'
      exit 1
    fi

    echo
    echo 'MySQL init process done. Ready for start up.'
    echo
    #mv /etc/my.cnf $DATADIR
  fi
fi

#--log-error=${DATADIR}error.log
exec mysqld --user=mysql --wsrep_sst_auth="xtrabackup:$XTRABACKUP_PASSWORD" $CMDARG
sleep 1000
