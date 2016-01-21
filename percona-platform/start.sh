#!/usr/bin/env bash

set -eu

service mysql start

# Restore group so Graf can read its config file.
chgrp grafana /etc/grafana/grafana.ini

# It takes Graf a second or two to become available, so wait and then create the data source.
service grafana-server start
for i in `seq 30`; do
	if curl -s http://admin:admin@localhost:3000/api/datasources; then
		curl -s -H "Content-Type: application/json" -X POST --data-binary @/root/prometheus-datasource.json http://admin:admin@localhost:3000/api/datasources > /dev/null
		echo "Added Prometheus data source to Grafana"
		break
	else
		echo "Waiting for Grafana..."
		sleep 1
	fi
done

# Unpack and run Prometheus, replacing ":NODE_IP" in its config with the one given via "docker run -e NODE_IP=".
cd ~
tar xvfz prometheus-0.16.2.linux-amd64.tar.gz > /dev/null
sed -e "s/:NODE_IP/$NODE_IP/g" /root/prometheus.yml > ./prometheus-0.16.2.linux-amd64/prometheus.yml
cd prometheus-0.16.2.linux-amd64
./prometheus -config.file=prometheus.yml > log 2>&1 &

# Install and run the Percona Datastore/API.
cd ~
PKG="ppl-datastore"
URL="https://www.percona.com/downloads/TESTING/ppl/open-source/${PKG}.tar.gz"
[ -d $PKG ] && rm -rf $PKG
mkdir $PKG
echo "Downloading $URL..."
curl -LO $URL
tar xvfz ${PKG}.tar.gz -C $PKG > /dev/null
echo "Installing `ls -d $PKG/percona-datastore-*`"
cd $PKG/*
HOSTNAME="${API_HOSTNAME:-""}" LISTEN="${API_LISTEN:-""}" ./install

# Install the Percona Query Analytics app, but don't run it yet...
cd ~
PKG="ppl-qan-app"
URL="https://www.percona.com/downloads/TESTING/ppl/open-source/${PKG}.tar.gz"
[ -d $PKG ] && rm -rf $PKG
mkdir $PKG
echo "Downloading $URL..."
curl -LO $URL
tar xvfz ${PKG}.tar.gz -C $PKG > /dev/null
echo "Installing `ls -d $PKG/percona-qan-app-*`"
cd ${PKG}/*
START="no" LISTEN="${APP_LISTEN:-""}" ./install

# Now run the app, which keeps the container alive.
cd /usr/local/percona/qan-app
BG="no" ./start
