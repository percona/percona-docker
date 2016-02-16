#!/usr/bin/env bash

set -eu

service mysql start

cd /opt/qan-api
START="no" HOSTNAME="${API_HOSTNAME:-""}" LISTEN="${API_LISTEN:-""}" ./install
