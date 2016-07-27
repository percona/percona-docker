REPLICASET_NAME=${REPLICASET_NAME:-replset1}
NODE_NAME=${NODE_NAME:-${REPLICASET_NAME}_master}
NETWORK_NAME=${REPLICASET_NAME}_net

docker network create -d overlay $NETWORK_NAME

  echo "Starting new node..."
docker run -d -p 3306:3306 --net=$NETWORK_NAME \
         --name=$NODE_NAME \
	 -e MYSQL_ROOT_PASSWORD=Theistareyk \
	 perconalab/ps-master-slave --innodb-buffer-pool-size=2G 

#--gtid-mode=ON --enforce-gtid-consistency
#--general-log=1 --general_log_file=/var/lib/mysql/general.log
echo "Started $(docker ps -l -q)"

