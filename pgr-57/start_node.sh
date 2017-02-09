CLUSTER_NAME=${CLUSTER_NAME:-Theistareykjarbunga}
NETWORK_NAME=${CLUSTER_NAME}_net
mysql_password=Theistareyk
nodes=3

docker network create $NETWORK_NAME
sleep 2

echo "Starting new node..."
ID=$(docker run -d -p 3306 --net=$NETWORK_NAME \
	 -e MYSQL_ROOT_PASSWORD=$mysql_password \
	 -e CLUSTER_NAME=${CLUSTER_NAME} \
	 perconalab/pgr-57)

if [ -z "$ID" ] ; then 
    echo "Failed to start the container!"
    exit 1
fi

echo "Started $ID"
hostn=$(docker inspect --format '{{ .Config.Hostname }}' $ID)
echo "ID : $hostn"

sleep 10

docker exec -it $hostn mysql -uroot -p$mysql_password -e "SET GLOBAL group_replication_bootstrap_group=ON;START GROUP_REPLICATION;SET GLOBAL group_replication_bootstrap_group=OFF;"


for i in $(seq 2 $nodes)
do
echo "Starting extra node $i"
ID=$(docker run -d -p 3306 --net=$NETWORK_NAME \
	 -e MYSQL_ROOT_PASSWORD=$mysql_password \
	 -e CLUSTER_NAME=${CLUSTER_NAME} \
	 -e CLUSTER_JOIN=$hostn \
	 perconalab/pgr-57)

if [ -z "$ID" ] ; then 
    echo "Failed to start the container!"
    exit 1
fi

echo "Started $ID"
hostnode=$(docker inspect --format '{{ .Config.Hostname }}' $ID)
echo "ID : $hostnode"

sleep 10

docker exec -it $hostnode mysql -uroot -p$mysql_password -e "SET GLOBAL group_replication_allow_local_disjoint_gtids_join=ON;START GROUP_REPLICATION;SET GLOBAL group_replication_allow_local_disjoint_gtids_join=OFF;"
done
