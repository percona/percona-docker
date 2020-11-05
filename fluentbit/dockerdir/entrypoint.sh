#!/bin/sh
set -e
set -o xtrace

export PATH=$PATH:/opt/td-agent-bit/bin

if [ "$1" = 'fluent-bit' ]; then
    fluentbit_opt+='-c /etc/fluentbit/fluentbit.conf'
fi
exec "$@" $fluentbit_opt
