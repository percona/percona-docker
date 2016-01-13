#!/usr/bin/env bash

set -eu

service mysql start

cd ~
PKG="percona-datastore-1.0.0-20160112.ed7d5e2"
curl -LO https://www.percona.com/redir/downloads/TESTING/ppl/open-source/${PKG}.tar.gz
tar xvfz ${PKG}.tar.gz
cd $PKG
./install

cd ~
PKG="percona-qan-app-1.0.0-20160112.ebbc7f7"
curl -LO https://www.percona.com/redir/downloads/TESTING/ppl/open-source/${PKG}.tar.gz
tar xvfz ${PKG}.tar.gz
cd ${PKG}
START="no" ./install

cd /usr/local/percona/qan-app
BG="no" ./start
