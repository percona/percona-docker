#!/bin/sh
set -e

log() {
    local message=$1
    local date=$(/usr/bin/date +"[%d/%b/%Y:%H:%M:%S.%3N]")

    echo "${date} ${message}"
}

if [ "$1" = 'haproxy' ]; then
    if [ ! -f '/etc/haproxy/pxc/haproxy.cfg' ]; then
        log '/etc/haproxy/haproxy.cfg /etc/haproxy/pxc'
        cp /etc/haproxy/haproxy.cfg /etc/haproxy/pxc
    fi

    custom_conf='/etc/haproxy-custom/haproxy-global.cfg'
    if [ -f "$custom_conf" ]; then
        log "haproxy -c -f $custom_conf -f /etc/haproxy/pxc/haproxy.cfg"
        haproxy -c -f $custom_conf -f /etc/haproxy/pxc/haproxy.cfg || EC=$?
        if [ -n "$EC" ]; then
            log "The custom config $custom_conf is not valid and will be ignored."
        fi
    fi

    haproxy_opt='-W -db '
    if [ -f "$custom_conf" -a -z "$EC" ]; then
        haproxy_opt+="-f $custom_conf "
    else
        haproxy_opt+='-f /etc/haproxy/haproxy-global.cfg '
    fi
    haproxy_opt+='-f /etc/haproxy/pxc/haproxy.cfg -p /etc/haproxy/pxc/haproxy.pid -S /etc/haproxy/pxc/haproxy-main.sock '
fi

log 'test -e /opt/percona/hookscript/hook.sh && source /opt/percona/hookscript/hook.sh'
test -e /opt/percona/hookscript/hook.sh && source /opt/percona/hookscript/hook.sh

log "$@ $haproxy_opt"
exec "$@" $haproxy_opt
