#!/bin/bash

set -eu

cd /opt/qan-agent
./install -interactive=false -auto-detect-mysql=false \
	-mysql-host=$MYSQL_IP -mysql-user=$MYSQL_USER -mysql-pass=$MYSQL_PASSWORD \
	-create-mysql-user=false -agent-mysql-user=pmm-client -agent-mysql-pass=percona2016 \
	$NODE_IP

cd /opt
supervisord -c /etc/supervisord.conf
