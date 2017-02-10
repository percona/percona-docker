#!/bin/bash
set -e

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	CMDARG="$@"
fi

if [ -z "$CLUSTER_NAME" ]; then
	echo >&2 'Error:  You need to specify CLUSTER_NAME'
	exit 1
fi

	# Get config
	DATADIR="$("mysqld" --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"

	if [ ! -e "$DATADIR/init.ok" ]; then
		if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
                        echo >&2 'error: database is uninitialized and password option is not specified '
                        echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
                        exit 1
                fi
		mkdir -p "$DATADIR"

		echo "Running mysql_install_db to $DATADIR"
		ls -lah "$DATADIR"
		mysql_install_db --datadir="$DATADIR"
		chown -R mysql:mysql "$DATADIR"
		chown mysql:mysql /var/log/mysqld.log
		echo 'Finished mysql_install_db'

		tempSqlFile='/tmp/mysql-first-time.sql'
		set -- "$@" --init-file="$tempSqlFile"

		if [ ! -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
			MYSQL_ROOT_PASSWORD="$(pwmake 128)"
			echo "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
		fi
		cat >> "$tempSqlFile" <<-EOSQL
			-- What's done in this file shouldn't be replicated
			--  or products like mysql-fabric won't work
			SET @@SESSION.SQL_LOG_BIN=0;
			CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
			GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
			ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
			CREATE USER 'xtrabackup'@'localhost' IDENTIFIED BY '$XTRABACKUP_PASSWORD';
			GRANT RELOAD,PROCESS,LOCK TABLES,REPLICATION CLIENT ON *.* TO 'xtrabackup'@'localhost';
			GRANT REPLICATION CLIENT ON *.* TO monitor@'%' IDENTIFIED BY 'monitor';
			GRANT PROCESS ON *.* TO monitor@localhost IDENTIFIED BY 'monitor';
			DROP DATABASE IF EXISTS test;
			FLUSH PRIVILEGES;
		EOSQL
		# sed is for https://bugs.mysql.com/bug.php?id=20545
		echo "$(mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/FCTY/')" >> "$tempSqlFile"

		if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
			mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
		fi

		if [ "$MYSQL_DATABASE" ]; then
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`;" >> "$tempSqlFile"
			mysql+=( "$MYSQL_DATABASE" )
		fi

		if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
			echo "CREATE USER '"$MYSQL_USER"'@'%' IDENTIFIED BY '"$MYSQL_PASSWORD"';" >> "$tempSqlFile"

			if [ "$MYSQL_DATABASE" ]; then
				echo "GRANT ALL ON \`"$MYSQL_DATABASE"\`.* TO '"$MYSQL_USER"'@'%';" >> "$tempSqlFile"
			fi

			echo 'FLUSH PRIVILEGES;' >> "$tempSqlFile"
		fi

		if [ ! -z "$MYSQL_ONETIME_PASSWORD" ]; then
			cat >> "$tempSqlFile" <<-EOSQL
				ALTER USER 'root'@'%' PASSWORD EXPIRE;
			EOSQL
		fi

		echo
		echo 'MySQL first time init prepareation done. Ready for start up.'
		echo
	fi
	touch $DATADIR/init.ok
	chown -R mysql:mysql "$DATADIR"

if [ -z "$DISCOVERY_SERVICE" ]; then
	cluster_join=$CLUSTER_JOIN
else
	echo
    echo '-> Registering in the discovery service'
    echo

    function join {
        local IFS="$1"
        shift
        joined=$(tr "$IFS" '\n' <<< "$*" | sort -un | tr '\n' "$IFS")
        echo "${joined%?}"
    }

    # Read the list of registered IP addresses
    set +e

    ipaddr=$(hostname -i | awk ' { print $1 } ')
    hostname=$(hostname)

    curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/queue/$CLUSTER_NAME -XPOST -d value=$ipaddr -d ttl=60

    #get list of IP from queue
    i=$(curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/queue/$CLUSTER_NAME | jq -r '.node.nodes[].value')

    # this remove my ip from the list
    i1="${i[@]/$ipaddr}"
    cluster_join1=$(join , $i1)

    # Register the current IP in the discovery service

    # key set to expire in 30 sec. There is a cronjob that should update them regularly
    curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/$ipaddr/ipaddr -XPUT -d value="$ipaddr" -d ttl=30
    curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/$ipaddr/hostname -XPUT -d value="$hostname" -d ttl=30
    curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/$ipaddr -XPUT -d ttl=30 -d dir=true -d prevExist=true

    #i=`curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/ | jq -r '.node.nodes[].value'`
    i=$(curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/?quorum=true | jq -r '.node.nodes[]?.key' | awk -F'/' '{print $(NF)}')
    # this remove my ip from the list
    i2="${i[@]/$ipaddr}"
    cluster_join=$(join , $i1 $i2 )
    echo "Joining cluster $cluster_join"

    /usr/bin/clustercheckcron monitor monitor 1 /var/lib/mysql/clustercheck.log 1 &
    set -e
	cat > /etc/my.cnf/wsrep.cnf <<EOF
[mysqld]

user = mysql
datadir=/var/lib/mysql

log_error = "${DATADIR}/error.log"

default_storage_engine=InnoDB
binlog_format=ROW

innodb_flush_log_at_trx_commit = 0
innodb_flush_method            = O_DIRECT
innodb_file_per_table          = 1
innodb_autoinc_lock_mode       = 2

bind_address = 0.0.0.0

wsrep_slave_threads = 2
wsrep_cluster_address = gcomm://$cluster_join
wsrep_provider = /usr/lib/galera3/libgalera_smm.so
wsrep_node_address = $ipaddr

wsrep_cluster_name="$CLUSTER_NAME"

wsrep_sst_method = xtrabackup-v2
wsrep_sst_auth = "xtrabackup:$XTRABACKUP_PASSWORD"
EOF
fi

exec "$@" "$CMDARG"
