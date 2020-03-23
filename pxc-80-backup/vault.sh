#!/bin/bash

set -o errexit

function parse_ini() {
  local key=$1
  local file_path=$2

  awk -F "=[ ]*" "/${key}[ ]*=/ {print \$2}" "$file_path"
}

function vault_get() {
  local sst_info=$1
  local keyring_vault=/etc/mysql/vault-keyring-secret/keyring_vault.conf

  if [ ! -f $keyring_vault ]; then
    return 0
  fi

  if [ ! -f $sst_info ]; then
    return 0
  fi

  export VAULT_TOKEN=$(parse_ini "token" "${keyring_vault}")
  export VAULT_ADDR=$(parse_ini "vault_url" "${keyring_vault}")
  local vault_root=$(parse_ini "secret_mount_point" "${keyring_vault}")/backup
  local gtid=$(parse_ini "galera-gtid" "${sst_info}")

  vault kv get "${vault_root}/${gtid}" \
      | grep transition_key \
      | sed -e 's/transition_key[[:space:]]*//g'
}

function vault_store() {
  local sst_info=$1
  local keyring_vault=/etc/mysql/vault-keyring-secret/keyring_vault.conf

  if [ ! -f $keyring_vault ]; then
    echo "vault configuration not found"
    return 0
  fi

  if [ ! -f $sst_info ]; then
    echo "SST info not found"
    return 0
  fi

  set +o xtrace # hide sensitive information
  export VAULT_TOKEN=$(parse_ini "token" "${keyring_vault}")
  export VAULT_ADDR=$(parse_ini "vault_url" "${keyring_vault}")
  local vault_root=$(parse_ini "secret_mount_point" "${keyring_vault}")/backup
  local transition_key=$(parse_ini "transition-key" "${sst_info}")
  local gtid=$(parse_ini "galera-gtid" "${sst_info}")

  if [ -z "${transition_key}" ]; then
    echo "no transition key in the SST info: backup is an unencrypted, or it was already processed"
    return 0
  fi

  vault kv put ${vault_root}/${gtid} "transition_key=${transition_key}"
  vault kv get "${vault_root}/${gtid}" >/dev/null
  set -o xtrace
  sed -i '/transition-key/d' $sst_info >/dev/null
}
