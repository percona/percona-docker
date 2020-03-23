#!/bin/bash

set -o errexit

VAULT_CONF=/etc/mysql/vault-keyring-secret/keyring_vault.conf
SST_INFO=/datadir/sst_info

vault_get() {
  if [ ! -f $VAULT_CONF ]
  then
    return 0
  fi

  if [ ! -f $SST_INFO ]
  then
    return 0
  fi

  export VAULT_TOKEN=`grep "token[[:space:]]=" $VAULT_CONF | cut -d "=" -f 2 | sed -e 's/[[:space:]]//g'`
  export VAULT_ADDR=`grep "vault_url[[:space:]]=" $VAULT_CONF | cut -d "=" -f 2 | sed -e 's/[[:space:]]//g'`
  VAULT_ROOT=`grep "secret_mount_point[[:space:]]=" $VAULT_CONF | cut -d "=" -f 2 | sed -e 's/[[:space:]]//g'`/backup

  GTID=`grep -a galera-gtid $SST_INFO | cut -d '=' -f 2`

  vault kv get $VAULT_ROOT/$GTID | grep transition_key | sed -e 's/transition_key[[:space:]]*//g'
}