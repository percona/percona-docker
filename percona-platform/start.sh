#!/usr/bin/env bash

set -eu

service mysql start

export HOSTNAME="${HOSTNAME:-"$(hostname -f)"}"

cd ~
PKG="ppl-datastore"
[ -d $PKG ] && rm -rf $PKG
mkdir $PKG
curl -LO https://www.percona.com/downloads/TESTING/ppl/open-source/${PKG}.tar.gz
tar xvfz ${PKG}.tar.gz -C $PKG
cd $PKG/*
./install

cd ~
PKG="ppl-qan-app"
[ -d $PKG ] && rm -rf $PKG
mkdir $PKG
curl -LO https://www.percona.com/downloads/TESTING/ppl/open-source/${PKG}.tar.gz
tar xvfz ${PKG}.tar.gz -C $PKG
cd ${PKG}/*
START="no" ./install

cd /usr/local/percona/qan-app
BG="no" ./start
