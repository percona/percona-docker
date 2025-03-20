#!/bin/bash

PATRONI_PORT=8008
PATRONI_HOST=localhost

curl -k "http://${PATRONI_HOST}:${PATRONI_PORT}/readiness"
