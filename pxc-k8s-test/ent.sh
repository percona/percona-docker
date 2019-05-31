#!/bin/bash
set -x

USER_ID=$(id -u)
_MYSQL_ROOT_HOST="${MYSQL_ROOT_HOST:-%}"
#echo "$_MYSQL_ROOT_HOST:$MYSQL_ROOT_HOST" > /tmp/env

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
  CMDARG="$@"
fi

# Is running in Kubernetes/OpenShift, so find all other pods
# belonging to the namespace
echo "Percona XtraDB Cluster: Finding peers"
PXC_SERVICE=${PXC_SERVICE:-$(hostname -f | cut -d"." -f2)}
echo "Using service name: ${PXC_SERVICE}"
/usr/bin/peer-list -on-start="/usr/bin/configure-pxc.sh" -service=${PXC_SERVICE}

# Get config
DATADIR="$("mysqld" --verbose --wsrep_provider= --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"
if [ -z "$WSREP_CLUSTER_ADDRESS" ]; then
  DATADIR="/var/lib/mysql"
fi

# if we have CLUSTER_JOIN - then we do not need to perform datadir initialize
# the data will be copied from another node
cat /etc/mysql/node.cnf
WSREP_CLUSTER_ADDRESS=$(grep wsrep_cluster_address /etc/mysql/node.cnf | sed -e 's^.*gcomm://^^')
echo "Cluster address set to: $WSREP_CLUSTER_ADDRESS"

if [ -z "$WSREP_CLUSTER_ADDRESS" ]; then

  echo "Cluster address is empty! "

  if [ ! -z "$MYSQL_INIT_DATADIR" ]; then
    echo "Need to perform initial cleanup"
    # Cleanup directory
    # ls -lahR "$DATADIR"
    rm -fr $DATADIR/*
  fi

  if [ ! -e "$DATADIR/mysql" ]; then
    echo "Running with password ::$MYSQL_ROOT_PASSWORD::"
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
    "${mysql[@]}" <<-EOSQL
                    -- What's done in this file shouldn't be replicated
                    --  or products like mysql-fabric won't work
                    SET @@SESSION.SQL_LOG_BIN=0;
                    CREATE USER 'root'@'${_MYSQL_ROOT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
                    GRANT ALL ON *.* TO 'root'@'${_MYSQL_ROOT_HOST}' WITH GRANT OPTION ;
                    ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
                    CREATE USER 'xtrabackup'@'localhost' IDENTIFIED BY '$XTRABACKUP_PASSWORD';
                    GRANT RELOAD,PROCESS,LOCK TABLES,REPLICATION CLIENT ON *.* TO 'xtrabackup'@'localhost';
                    GRANT SELECT, PROCESS, SUPER, REPLICATION CLIENT, RELOAD ON *.* TO 'monitor'@'localhost' IDENTIFIED BY '$MONITOR_PASSWORD';
                    GRANT SELECT, UPDATE, DELETE, DROP ON performance_schema.* TO 'monitor'@'localhost';
                    GRANT PROCESS ON *.* TO 'clustercheck'@'localhost' IDENTIFIED BY '$CLUSTERCHECK_PASSWORD';
                    DROP DATABASE IF EXISTS test ;
EOSQL

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

    echo "${mysql[@]}" >/tmp/mysql_init

    echo
    echo 'MySQL init process done. Ready for start up.'
    echo
    #mv /etc/my.cnf $DATADIR
  fi
  #else
  # Cleanup directory
  #rm -fr $DATADIR/*
fi
#--log-error=${DATADIR}error.log
ncat --listen --keep-open --send-only --max-conns=1 3307 -c \
  "mysql -uroot -p$MYSQL_ROOT_PASSWORD -e 'set global wsrep_desync=on' > /dev/null 2>&1;  xtrabackup --backup --slave-info --galera-info --stream=xbstream --host=127.0.0.1 --user=xtrabackup --password=$XTRABACKUP_PASSWORD --target-dir=/tmp; mysql -uroot -p$MYSQL_ROOT_PASSWORD -e 'set global wsrep_desync=off' > /dev/null 2>&1" >/tmp/ncat_xtrabackup.log &

exec mysqld --user=mysql --wsrep_sst_auth="xtrabackup:$XTRABACKUP_PASSWORD" $CMDARG
