#!/bin/sh
set -e
set -o xtrace

if [ "$1" = 'haproxy' ]; then
    haproxy_opt='-W -db '
    cp /etc/haproxy/haproxy.cfg /etc/haproxy/pxc
    if [ -f '/etc/haproxy-custom/haproxy-global.cfg' ]; then
        haproxy_opt+='-f /etc/haproxy-custom/haproxy-global.cfg '
    else
        haproxy_opt+='-f /etc/haproxy/haproxy-global.cfg '
    fi
    haproxy_opt+='-f /etc/haproxy/pxc/haproxy.cfg -p /etc/haproxy/pxc/haproxy.pid -S /etc/haproxy/pxc/haproxy-master.sock '
fi
exec "$@" $haproxy_opt
