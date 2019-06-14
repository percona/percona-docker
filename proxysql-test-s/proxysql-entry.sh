#!/bin/bash
set -e

## ProxySQL entrypoint
## ===================
##
## Supported environment variable:
##
## MONITOR_CONFIG_CHANGE={true|false}
## - Monitor /etc/proxysql.cnf for any changes and reload ProxySQL automatically

# If command has arguments, prepend proxysql
if [ "${1:0:1}" = '-' ]; then
  CMDARG="$@"
fi

# Check that PEERS are set
if [ -z "$PEERS_GOV_SVC" ]; then
  echo "Need to pass PEERS variables in the YAML file or set PEERS env variable. Exiting ..."
  exit
fi

function find_n_configure_proxysql() {
  # Platform is Kubernetes, so find all other pods
  # belonging to the namespace
  echo "Finding peers (backend pxc servers)"
  echo "Using service name: ${PEERS_GOV_SVC}"
  /usr/bin/peer-finder -on-start="/usr/bin/configure-proxysql.sh" -service=${PEERS_GOV_SVC}
}

if [ $MONITOR_CONFIG_CHANGE ]; then

  echo 'Env MONITOR_CONFIG_CHANGE=true'
  CONFIG=/etc/proxysql.cnf
  oldcksum=$(cksum ${CONFIG})

  # Start ProxySQL in the background
  proxysql --reload -f $CMDARG &

  echo "configuring proxysql.."
  #  find_n_configure_proxysql

  echo "Monitoring $CONFIG for changes.."
  inotifywait -e modify,move,create,delete -m --timefmt '%d/%m/%y %H:%M' --format '%T' ${CONFIG} |
    while read date time; do
      newcksum=$(cksum ${CONFIG})
      if [ "$newcksum" != "$oldcksum" ]; then
        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo "At ${time} on ${date}, ${CONFIG} update detected."
        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        oldcksum=$newcksum
        echo "Reloading ProxySQL.."
        killall -15 proxysql
        proxysql --initial --reload -f $CMDARG
      fi
    done
fi

# Start ProxySQL with PID 1
exec proxysql -f $CMDARG &
pid=$!

echo "configuring proxysql.."
#find_n_configure_proxysql
# Platform is Kubernetes, so find all other pods
# belonging to the namespace
echo "Finding peers (backend pxc servers)"
echo "Using service name: ${PEERS_GOV_SVC}"
#/usr/bin/peer-finder -on-start="/usr/bin/configure-proxysql.sh" -service=${PEERS_GOV_SVC}
/usr/bin/configure-proxysql.sh
echo "+++++++++++ hey, waiting to complete proxysql..."

wait $pid
