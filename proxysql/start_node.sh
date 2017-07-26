CLUSTER_NAME=${CLUSTER_NAME:-Theistareykjarbunga}
ETCD_HOST=${ETCD_HOST:-10.20.2.4:2379}
NETWORK_NAME=${CLUSTER_NAME}_net

echo "Starting new ProxySQL on $NETWORK_NAME ..."
docker run -d -p 3306:3306 -p 6032:6032 --net=$NETWORK_NAME --name=${CLUSTER_NAME}_proxysql \
        -e CLUSTER_NAME=$CLUSTER_NAME \
        -e DISCOVERY_SERVICE=$ETCD_HOST \
        -e MYSQL_ROOT_PASSWORD=Theistareyk \
        -e MYSQL_PROXY_USER=proxyuser \
        -e MYSQL_PROXY_PASSWORD=s3cret \
        perconalab/proxysql
echo "Started $(docker ps -l -q)"
