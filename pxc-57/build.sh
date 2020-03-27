#!/bin/bash
set -eo pipefail
shopt -s nullglob
set -o xtrace

tag=$(docker build -t percona-xtradb-cluster-operator:K8SPXC-172-pxc5.7 . | grep -E "^Successfully built .*" | awk '{print $3}' )
echo "$tag"
docker tag "$tag" perconalab/percona-xtradb-cluster-operator:K8SPXC-172-pxc5.7
docker push perconalab/percona-xtradb-cluster-operator:K8SPXC-172-pxc5.7