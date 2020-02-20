#!/bin/bash
set -o errexit
set -o xtrace

imageID=$(docker build -t percona-xtradb-cluster-operator:master-pxc8.0 . | grep "Successfully built" | awk '{print $3}')
if [ -z "${imageID}" ]; then
    echo "error happened"
    exit 1
fi
docker tag "$imageID" perconalab/percona-xtradb-cluster-operator:master-pxc8.0
docker push perconalab/percona-xtradb-cluster-operator:master-pxc8.0
