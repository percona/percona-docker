#!/usr/bin/env bash

set -eu

service mysql start

# START=no SYSINT=no because Supervisor starts and manages these processes.

cd /opt/qan-api
START="no" SYSINT="no" ./install

cd /opt/qan-app
START="no" SYSINT="no" LISTEN="0.0.0.0:9002" ./install
