#!/bin/sh
set -e
set -o xtrace

if [ "$1" = 'haproxy' ]; then
    haproxy_opt='-W -db '
    cp /etc/haproxy/haproxy.cfg /etc/haproxy/pxc
    custom_conf='/etc/haproxy-custom/haproxy-global.cfg'
    if [ -f "$custom_conf" ]; then
        haproxy -c -f $custom_conf -f /etc/haproxy/pxc/haproxy.cfg || EC=$?
        if [ -n "$EC" ]; then
            echo "The custom config $custom_conf is not valid and will be ignored."
        fi
    fi

    if [ -f "$custom_conf" -a -z "$EC" ]; then
        haproxy_opt+="-f $custom_conf "
    else
        haproxy_opt+='-f /etc/haproxy/haproxy-global.cfg '
    fi
    haproxy_opt+='-f /etc/haproxy/pxc/haproxy.cfg -p /etc/haproxy/pxc/haproxy.pid -S /etc/haproxy/pxc/haproxy-master.sock '
fi
exec "$@" $haproxy_opt
