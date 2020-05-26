#! /bin/bash

# Copyright 2016 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script writes out a mysql galera config using a list of newline seperated
# peer DNS names it accepts through stdin.

# /etc/mysql is assumed to be a shared volume so we can modify my.cnf as required
# to keep the config up to date, without wrapping mysqld in a custom pid1.
# The config location is intentionally not /etc/mysql/my.cnf because the
# standard base image clobbers that location.

set -o errexit
set -o xtrace

function join {
    local IFS="$1"; shift; echo "$*";
}

NODE_IP=$(hostname -I | awk ' { print $1 } ')
CLUSTER_NAME="$(hostname -f | cut -d'.' -f2)"
SERVER_ID=${HOSTNAME/$CLUSTER_NAME-}
NODE_NAME=$(hostname -f)
NODE_PORT=3306

while read -ra LINE; do
    echo "read line $LINE"
    LINE_IP=$(getent hosts "$LINE" | awk '{ print $1 }')
    if [ "$LINE_IP" != "$NODE_IP" ]; then
        PEERS=("${PEERS[@]}" $LINE_IP)
    fi
done

if [ "${#PEERS[@]}" != 0 ]; then
    WSREP_CLUSTER_ADDRESS=$(join , "${PEERS[@]}")
fi

CFG=/etc/mysql/node.cnf
sed -r "s|^[#]?server_id=.*$|server_id=1${SERVER_ID}|" ${CFG} 1<> ${CFG}
sed -r "s|^[#]?wsrep_node_address=.*$|wsrep_node_address=${NODE_IP}|" ${CFG} 1<> ${CFG}
sed -r "s|^[#]?wsrep_cluster_name=.*$|wsrep_cluster_name=${CLUSTER_NAME}|" ${CFG} 1<> ${CFG}
sed -r "s|^[#]?wsrep_cluster_address=.*$|wsrep_cluster_address=gcomm://${WSREP_CLUSTER_ADDRESS}|" ${CFG} 1<> ${CFG}
sed -r "s|^[#]?wsrep_node_incoming_address=.*$|wsrep_node_incoming_address=${NODE_NAME}:${NODE_PORT}|" ${CFG} 1<> ${CFG}
sed -r "s|^[#]?wsrep_sst_auth=.*$|wsrep_sst_auth='xtrabackup:$XTRABACKUP_PASSWORD'|" ${CFG} 1<> ${CFG}

CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
if [ -f /var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt ]; then
    CA=/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt
fi
SSL_DIR=${SSL_DIR:-/etc/mysql/ssl}
if [ -f ${SSL_DIR}/ca.crt ]; then
    CA=${SSL_DIR}/ca.crt
fi
SSL_INTERNAL_DIR=${SSL_INTERNAL_DIR:-/etc/mysql/ssl-internal}
if [ -f ${SSL_INTERNAL_DIR}/ca.crt ]; then
    CA=${SSL_INTERNAL_DIR}/ca.crt
fi

KEY=${SSL_DIR}/tls.key
CERT=${SSL_DIR}/tls.crt
if [ -f ${SSL_INTERNAL_DIR}/tls.key -a -f ${SSL_INTERNAL_DIR}/tls.crt ]; then
    KEY=${SSL_INTERNAL_DIR}/tls.key
    CERT=${SSL_INTERNAL_DIR}/tls.crt
fi

if [ -f $CA -a -f $KEY -a -f $CERT ]; then
    sed "/^\[mysqld\]/a pxc-encrypt-cluster-traffic=ON\nssl-ca=$CA\nssl-key=$KEY\nssl-cert=$CERT" ${CFG} 1<> ${CFG}
else
    sed "/^\[mysqld\]/a pxc-encrypt-cluster-traffic=OFF" ${CFG} 1<> ${CFG}
fi

# don't need a restart, we're just writing the conf in case there's an
# unexpected restart on the node.
