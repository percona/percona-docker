#!/bin/sh
set -e
set -o xtrace

if [ "$1" = 'haproxy' ]; then
    haproxy_opt='-W -db -f /etc/haproxy/pxc/haproxy.cfg '
    cp /etc/haproxy/haproxy.cfg /etc/haproxy/pxc
    if [ -f '/etc/haproxy-auto/haproxy-auto.cfg' ]; then
        haproxy_opt+='-f /etc/haproxy-auto/haproxy-auto.cfg '
    else
        haproxy_opt+='-f /etc/haproxy/haproxy-auto.cfg '
    fi
    haproxy_opt+='-p /etc/haproxy/pxc/haproxy.pid '
fi
exec "$@" $haproxy_opt
