CLUSTER_NAME=${CLUSTER_NAME:-Theistareykjarbunga}
ETCD_HOST=${ETCD_HOST:-10.20.2.4:2379}
NETWORK_NAME=${CLUSTER_NAME}_net

docker network create $NETWORK_NAME
# give it some time to create the newtork , otherwise the docker fails with - network not found
sleep 2
  echo "Starting new node..."
ID=$(docker run -d -p 3306 --net=$NETWORK_NAME \
	 -e MYSQL_ROOT_PASSWORD=Theistareyk \
	 -e DISCOVERY_SERVICE=$ETCD_HOST \
	 -e CLUSTER_NAME=${CLUSTER_NAME} \
	 -e XTRABACKUP_PASSWORD=Theistare \
	 percona/percona-xtradb-cluster)
#--general-log=1 --general_log_file=/var/lib/mysql/general.log

if [ -z "$ID" ] ; then 
    echo "Failed to start the container!"

else
    echo "Started $ID"
fi

# --wsrep_cluster_address="gcomm://$QCOMM"
