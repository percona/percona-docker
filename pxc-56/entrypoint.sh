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
	DATADIR="$("mysqld" --verbose --wsrep_on=OFF --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"

	if [ ! -e "$DATADIR/init.ok" ]; then
		if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" -a -z "$MYSQL_ROOT_PASSWORD_FILE" ]; then
                        echo >&2 'error: database is uninitialized and password option is not specified '
                        echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ROOT_PASSWORD_FILE,  MYSQL_ALLOW_EMPTY_PASSWORD or MYSQL_RANDOM_ROOT_PASSWORD'
                        exit 1
                fi

		if [ ! -z "$MYSQL_ROOT_PASSWORD_FILE" -a -z "$MYSQL_ROOT_PASSWORD" ]; then
		  MYSQL_ROOT_PASSWORD=$(cat $MYSQL_ROOT_PASSWORD_FILE)
		fi

		mkdir -p "$DATADIR"

		echo 'Running mysql_install_db'
		mysql_install_db --user=mysql --wsrep_on=OFF --datadir="$DATADIR" --rpm --keep-my-cnf
		echo 'Finished mysql_install_db'

		mysqld --no-defaults --user=mysql --wsrep_on=OFF --datadir="$DATADIR" --skip-networking &
		pid="$!"

		mysql=( mysql --protocol=socket -uroot )

		for i in {30..0}; do
			if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
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
                        DELETE FROM mysql.user ;
                        CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
                        GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
                        CREATE USER 'xtrabackup'@'localhost' IDENTIFIED BY '$XTRABACKUP_PASSWORD';
                        GRANT RELOAD,PROCESS,LOCK TABLES,REPLICATION CLIENT ON *.* TO 'xtrabackup'@'localhost';
			CREATE USER 'monitor'@'%' IDENTIFIED BY 'monitor';
                        GRANT REPLICATION CLIENT ON *.* TO 'monitor'@'%';
                        GRANT PROCESS ON *.* TO monitor@localhost IDENTIFIED BY 'monitor';
                        DROP DATABASE IF EXISTS test ;
                        FLUSH PRIVILEGES ;
		EOSQL
		if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
			mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
		fi

		if [ "$MYSQL_DATABASE" ]; then
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | "${mysql[@]}"
			mysql+=( "$MYSQL_DATABASE" )
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
	touch $DATADIR/init.ok

if [ -z "$DISCOVERY_SERVICE" ]; then
    cluster_join=$CLUSTER_JOIN
else

    echo
    echo 'Registering in the discovery service'
    echo

    function join { local IFS="$1"; shift; echo "$*"; }

# Read the list of registered IP addresses
    set +e

    ipaddr=$(hostname -I | awk ' { print $1 } ')
    hostname=$(hostname)

    curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/queue/$CLUSTER_NAME -XPOST -d value=$ipaddr -d ttl=60

#get list of IP from queue 
    i=$(curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/queue/$CLUSTER_NAME | jq -r '.node.nodes[].value')

# this to remove my ip from the list
    i1=${i[@]/$ipaddr}
    cluster_join1=$(join , $i1)

# Register the current IP in the discovery service

# key set to expire in 30 sec. There is a cronjob that should update them regularly

    curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/$ipaddr/ipaddr -XPUT -d value="$ipaddr" -d ttl=30
    curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/$ipaddr/hostname -XPUT -d value="$hostname" -d ttl=30
    curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/$ipaddr -XPUT -d ttl=30 -d dir=true -d prevExist=true

    i=$(curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/?quorum=true | jq -r '.node.nodes[]?.key' | awk -F'/' '{print $(NF)}')

# this removes my ip from the list

    i2=${i[@]/$ipaddr}
    cluster_join2=$(join , $i1)
    cluster_join=$(join , $i1 $i2 )

    echo "Joining cluster $cluster_join"

    /usr/bin/clustercheckcron monitor monitor 1 /var/lib/mysql/clustercheck.log 1 & 
    set -e

fi

exec mysqld --user=mysql --wsrep_cluster_name=$CLUSTER_NAME --wsrep_cluster_address="gcomm://$cluster_join" --wsrep_sst_method=xtrabackup-v2 --wsrep_sst_auth="xtrabackup:$XTRABACKUP_PASSWORD"  --wsrep_node_address="$ipaddr" $CMDARG

