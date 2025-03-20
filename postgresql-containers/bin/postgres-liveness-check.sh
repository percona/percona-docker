#!/bin/bash

PATRONI_PORT=8008
PATRONI_HOST=localhost

curl -k "https://${PATRONI_HOST}:${PATRONI_PORT}/liveness"
