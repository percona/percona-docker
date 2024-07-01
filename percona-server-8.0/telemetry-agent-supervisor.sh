#!/bin/bash

# phase-0 telemetry
/call-home.sh -f "PRODUCT_FAMILY_PS" -v "${PS_TELEMETRY_VERSION}" -d "DOCKER" ${CALL_HOME_OPTIONAL_PARAMS} &> /dev/null || :

# phase-1 telemetry
for i in {1..3}; do
    /usr/bin/percona-telemetry-agent >> /var/log/percona/telemetry-agent.log 2>> /var/log/percona/telemetry-agent-error.log
    if [ $? -eq 0 ]; then
      break
    fi
    sleep 5
done
sleep infinity
