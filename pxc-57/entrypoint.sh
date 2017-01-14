#!/bin/bash
set -e

cat<<TODO

    TODO
    dont create xtrabackup user if not in cluster mode
    check myIp logic when the service is part 

    HEALTHCHECK 
    mysql -srNe -p$MYSQL_ROOT_PASSWORD "SHOW GLOBAL STATUS LIKE 'wsrep_ready';" | awk '{ print $2; }'
    mysql -srNe "SHOW GLOBAL STATUS LIKE 'wsrep_ready';" | awk '{ print $2; }'


    RUN 
    docker service create \
    --publish 3306:3306 \
    --name mysql --replicas 3 \
    --network x \
    -e MYSQL_ROOT_PASSWORD=1 -e CLUSTER_NAME=cl  \
    --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
    --mount type=bind,src=/home/Dockers/dockerfiles/percona-docker/pxc-57/entrypoint.sh,dst=/entrypoint.sh \
    percona-xtradb-cluster bash -c "ping www.google.com"

    
    >>>>>>>>>>>>>>>>>>>>>>
TODO


# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	set -- mysqld --user=mysql "$@"
# in case you want to start the container with a different command
elif [ "$1" != "mysqld" ] || [ ! -z "$2" ]; then
    exec "$@"
    exit
else
    set -- "$@" --user=mysql
fi

	# Get config
	DATADIR="$("mysqld" --verbose --wsrep_provider= --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"

	if [ ! -d "$DATADIR/mysql" ]; then
		if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
                        echo >&2 'error: database is uninitialized and password option is not specified '
                        echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
                        exit 1
                fi
		mkdir -p "$DATADIR"

		echo "Running --initialize-insecure on $DATADIR"
		ls -lah $DATADIR
		mysqld --initialize-insecure
		chown -R mysql:mysql "$DATADIR"
		chown mysql:mysql /var/log/mysqld.log
		echo 'Finished --initialize-insecure'

                exec "$@" --datadir="$DATADIR" --skip-networking &
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
	fi
	chown -R mysql:mysql "$DATADIR"

#--log-error=${DATADIR}error.log
# run in standalone mode or as a cluster
if [ !  -z "$CLUSTER_NAME" ]; then
    containerId=$(cat /proc/self/cgroup |  awk -F  ":" '/pids/ {print $3}' | awk -F  "/" '{print $3}');
    serviceName=$(curl -s --unix-socket /var/run/docker.sock \
                    http://localhost/containers/$containerId/json  | \
                    jq -r '.Config.Labels["com.docker.swarm.service.name"]')

    if [ -z "$serviceName" ]; then
        echo  "to run as a cluster you need to run it  as a service"
        exit 1
    fi

    echo -e "Starting percona in a cluster  \n"

    myIp=$(dig -t A +short $(hostname))

    # get all task IP's (excluding non running, myIp and all ips from  the ingres network )
    readarray -t serviceIpArray <<< "$(curl -s --unix-socket /var/run/docker.sock \
            http://localhost/tasks?service=$serviceName | \
            jq -r '.[] | select(.Status.State == "running") | .NetworksAttachments[] | select(.Network.Spec.Name != "ingress") | .Addresses[] | select( . != "'"$myIp"'")' |\
            awk -F '/' {'print $1'})"

    echo -e "Trying to find a cluster node \n"

    # find at least one node from the cluster that is in a cluster state or bootstrap as a new cluster
    for nodeIp in "${serviceIpArray[@]}"; do
            nodeState=$(mysql -h $nodeIp -srN -p$MYSQL_ROOT_PASSWORD -e "SHOW GLOBAL STATUS LIKE 'wsrep_cluster_status';" 2>&1 | awk '/wsrep_cluster_status/ {print $2}')
            nodeState="${nodeState// /}" # trim empty space
            echo "Checking cluster state of service node: $nodeIp $nodeState"
            
            #  there is  a primary node or bootstrap the cluster
            if [ ! -z "$nodeState" ] || [ "$nodeIp" == "${serviceIpArray[-1]}" ]; then
                if [[ ! -z "$nodeState" ]]; then
                    echo -e  "Joining Primary cluster node : $nodeIp \n"
                    joinNode=$nodeIp
                else
                    # if no node is in primary state then wsrep_cluster_address will be empty and the cluster will bootstrap
                    echo "Boostraping a new cluster"
                fi

                exec "$@" --wsrep_cluster_name=$CLUSTER_NAME --wsrep_cluster_address="gcomm://$joinNode" --wsrep_sst_method=xtrabackup-v2 --wsrep_sst_auth="xtrabackup:$XTRABACKUP_PASSWORD" --wsrep_node_address="$myIp" 
            fi
    done
    
    
    # NOTE: the container healthcheck ensures that all de-synced nodes will be removed

else
    echo -e "Starting  percona in a standalone mode \n\n"
    exec "$@"
fi



