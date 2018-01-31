CLUSTER_NAME=${CLUSTER_NAME:-Theistareykjarbunga}
ETCD_HOST=${ETCD_HOST:-10.20.2.4:2379}
NETWORK_NAME=${CLUSTER_NAME}_net

docker network create -d overlay $NETWORK_NAME

  echo "Starting new node..."
docker run -d -p 3306 --net=$NETWORK_NAME \
	 -e MYSQL_ROOT_PASSWORD=Theistareyk \
	 -e DISCOVERY_SERVICE=$ETCD_HOST \
	 -e CLUSTER_NAME=${CLUSTER_NAME} \
	 -e XTRABACKUP_PASSWORD=Theistare \
	 percona/percona-xtradb-cluster
#--general-log=1 --general_log_file=/var/lib/mysql/general.log
echo "Started $(docker ps -l -q)"

# --wsrep_cluster_address="gcomm://$QCOMM"
