#!/usr/bin/env bash

set -eu

service mysql start

cd /opt/qan-api
START="no" ./install

cd /opt/qan-app
START="no" LISTEN="0.0.0.0:9002" ./install
