#!/usr/bin/env bash

set -eu

service mysql start

cd /opt/qan-api
START="no" ./install

cd /opt/qan-app
START="no" ./install
