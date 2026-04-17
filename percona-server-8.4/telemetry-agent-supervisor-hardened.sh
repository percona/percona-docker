#!/bin/sh
#
# telemetry-agent-supervisor-hardened.sh — POSIX sh rewrite for the hardened
# Percona Server 8.4 image.
#
# Differences from the non-hardened telemetry-agent-supervisor.sh:
#   - POSIX /bin/sh (dash), not /bin/bash — no readline/ncurses dep
#   - Phase-0 call-home.sh removed — it's a bash script from Percona-Lab,
#     and shipping it would require pulling bash + libreadline back into
#     the hardened image. The phase-0 ping is only a best-effort "install
#     detected" beacon; dropping it doesn't affect ongoing telemetry.
#   - Phase-1 (the Go binary `/usr/bin/percona-telemetry-agent`) is kept
#     unchanged — that's the real telemetry reporter.
#

set -e

# Retry percona-telemetry-agent up to 3 times, 5s apart, then sit idle.
i=1
while [ $i -le 3 ]; do
    if /usr/bin/percona-telemetry-agent \
            >> /var/log/percona/telemetry-agent.log \
            2>> /var/log/percona/telemetry-agent-error.log
    then
        break
    fi
    sleep 5
    i=$((i + 1))
done

exec sleep infinity
