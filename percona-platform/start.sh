#!/usr/bin/env bash

set -eu

service mysql start

[ "${API_PORT:-""}" ] && API_LISTEN="0.0.0.0:$API_PORT"

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

cd /usr/local/percona/qan-app
BG="no" ./start
