#!/bin/bash
set -eo pipefail
shopt -s nullglob

if [ ! -z "${PERCONA_INSTANCE_ID}" ]; then
  CALL_HOME_OPTIONAL_PARAMS+=" -i ${PERCONA_INSTANCE_ID}"
fi              
                        
if [ ! -z "${PERCONA_TELEMETRY_CONFIG_FILE_PATH}" ]; then
  CALL_HOME_OPTIONAL_PARAMS+=" -j ${PERCONA_TELEMETRY_CONFIG_FILE_PATH}"
fi      

if [ ! -z "${PERCONA_SEND_TIMEOUT}" ]; then
  CALL_HOME_OPTIONAL_PARAMS+=" -t ${PERCONA_SEND_TIMEOUT}"
else 
  CALL_HOME_OPTIONAL_PARAMS+=" -t 7"
fi 

if [ ! -z "${PERCONA_CONNECT_TIMEOUT}" ]; then
  CALL_HOME_OPTIONAL_PARAMS+=" -c ${PERCONA_CONNECT_TIMEOUT}"
else    
  CALL_HOME_OPTIONAL_PARAMS+=" -c 2"
fi     

# phase-0 telemetry
/call-home.sh -f "PRODUCT_FAMILY_PXB" -v "${PXB_TELEMETRY_VERSION}" -d "DOCKER" ${CALL_HOME_OPTIONAL_PARAMS} &> /dev/null || :

exec "$@"
