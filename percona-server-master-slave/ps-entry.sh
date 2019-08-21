#!/bin/bash
set -e

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	CMDARG="$@"
fi

#get server_id from ip address
ipaddr=$(hostname -I | awk ' { print $1 } ')
server_id=$(echo $ipaddr | tr . '\n' | awk '{s = s*256 + $1} END{print s}')

if [ -z "$MASTER_HOST" ]; then
# if master is not set - perform regular initialization

	if [ -n "$INIT_TOKUDB" ]; then
		export LD_PRELOAD=/lib64/libjemalloc.so.1
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

		echo 'Running --initialize-insecure'
		mysqld --initialize-insecure
		echo 'Finished --initialize-insecure'

		mysqld --user=mysql --datadir="$DATADIR" --skip-networking &
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
		# install TokuDB engine
		if [ -n "$INIT_TOKUDB" ]; then
			ps_tokudb_admin --enable
		fi

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

echo "Starting listener for slave requests"
/usr/bin/master_nc >> /tmp/master_nc.log &

exec mysqld --user=mysql --server-id=$server_id --log-error=${DATADIR}error.log $CMDARG

else
# perform slave routine
  set +e
  while : 
  do
  # do infinite loop till we can connect
  if  [ -z "$SLAVE_HOST" ]; then
    echo $ipaddr | nc ${MASTER_HOST} 4566
  else
    # connect to slave if defined
    echo $ipaddr | nc ${SLAVE_HOST} 4566
  fi
  if [ "$?" -eq 0 ]; then
     break
  fi
  echo "connection failed, trying again..."

  done
  set -e

  DATADIR=/var/lib/mysql
  cd $DATADIR
  
  echo "Receiving stream ..."
  nc -l -p 4565 | xbstream -x

  innobackupex --apply-log --use-memory=2G ./
  slavepass="$(pwmake 128)"
  mysql -h${MASTER_HOST} -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT REPLICATION SLAVE ON *.*  TO 'repl'@'$ipaddr' IDENTIFIED BY '$slavepass';"
  chown -R mysql:mysql "$DATADIR"

# start slave 
  echo "Starting slave..."
  mysqld --user=mysql --server-id=$server_id  $CMDARG &
  pid="$!"
  
  echo "Started with PID $pid, waiting for initialization..."
  set +e
    for i in {300..0}; do
	    mysql -uroot -p${MYSQL_ROOT_PASSWORD} -Bse "SELECT 1" mysql
	    if [ "$?" -eq 0 ]; then
		    break
	    else
		    echo 'MySQL init process in progress...'
		    sleep 5
	    fi
	    
    done
    if [ "$i" = 0 ]; then
	    echo >&2 'MySQL init process failed.'
	    exit 1
    fi


  if  [ -z "$SLAVE_HOST" ]; then
    binlogname=$(cat /var/lib/mysql/xtrabackup_binlog_info | awk ' { print $1 } ')
    binlogpos=$(cat /var/lib/mysql/xtrabackup_binlog_info | awk ' { print $2 } ')
    echo "Slave initialized, connecting to master with $binlogname:$binlogpos"
  
    mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CHANGE MASTER TO MASTER_HOST='${MASTER_HOST}', MASTER_USER='repl', MASTER_PASSWORD='$slavepass', MASTER_LOG_FILE='$binlogname', MASTER_LOG_POS=$binlogpos; START SLAVE"
  else
    mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "RESET SLAVE; CHANGE MASTER TO MASTER_HOST='${MASTER_HOST}', MASTER_USER='repl', MASTER_PASSWORD='$slavepass'"
    mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "$(cat xtrabackup_slave_info)"
    mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "START SLAVE"

  fi

  set -e

  echo "Starting listener for slave requests"
  /usr/bin/master_nc >> /tmp/master_nc.log &

  # loop while the process exist
  wait $pid

echo "mysqld process $pid has been terminated... exiting"
sleep 1000


fi


