#!/bin/sh
set -e
set -o xtrace

export PATH=$PATH:/opt/td-agent-bit/bin

if [  "$1" = 'logrotate' ]; then
    if [[ $EUID != 1001 ]]; then
        # logrotate requires UID in /etc/passwd
        sed -e "s^x:1001:^x:$EUID:^" /etc/passwd > /tmp/passwd
        cat /tmp/passwd > /etc/passwd
        rm -rf /tmp/passwd
    fi
    exec go-cron "0 0 * * *" logrotate -v -s /opt/percona/logrotate/logrotate.status /opt/percona/logrotate/logrotate-$SERVICE_TYPE.conf
else
    if [ "$1" = 'fluent-bit' ]; then
        fluentbit_opt+='-c /etc/fluentbit/fluentbit.conf'
    fi

    exec "$@" $fluentbit_opt
fi

