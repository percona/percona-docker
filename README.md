Percona XtraDB Cluster docker image
===================================

The docker image is available right now at `nlpsecure/percona-xtradb-57:latest`.
The image supports work in Docker Network, including overlay networks,
so that you can install Percona XtraDB Cluster nodes on different boxes.
There is an initial support for the etcd discovery service.

Basic usage
-----------

Create a Kubernetes cluster using Google's Kubernetes Engine at cloud.kubernetes.com with 1 node and availability in 3 zones in the same region.  Set up your command line tools according to [Google's](https://cloud.google.com/kubernetes-engine/docs/quickstart) docs and then after inspecting/editing to your preferences, run the following commands from the path of this README:

```bash
# Set your desired namespace here; I'm using pxc-test.  I do this just so that
# I can muck around and not accidentally break anything important without *really* trying.
kubectl config set-context $(kubectl config current-context) --namespace=pxc-test

# Note: the values in this file should be base64-encoded for k8s' consumption :)
kubectl create -f kubernetes/pxc-secrets.yml

kubectl create -f kubernetes/pxc-services.yml
kubectl create -f kubernetes/pxc-pv-host.yml
kubectl create -f kubernetes/pxc-statefulset.yml

# Watch your cluster come online with:
kubectl get pod

# As each member comes online, you can view its status with:
kubectl logs -f mysql-#
# Obviously, subsitute the node number up there.

# To rip the whole thing down for starting over is simple enough:
kubectl delete -f kubernetes/pxc-statefulset.yml; kubectl delete -f kubernetes/pxc-pv-host.yml; kubectl delete pvc --all

# Then you can boot a next iteration with:
kubectl create -f kubernetes/pxc-pv-host.yml; kubectl create -f kubernetes/pxc-statefulset.yml

# You can periodically delete nodes just to watch them come back online if you like;
# just don't delete all three at once - if you do this, you'll have to bootstrap,
# which is less than a fun day at the park.

# Once you're done, switch back to your default namespace with:
kubectl config set-context $(kubectl config current-context) --namespace=default

# If you were just testing, you can delete *everything* in one pass just by deleting the namespace:
kubectl delete ns pxc-test
```

Running with ProxySQL
---------------------

This section is to be re-added as a Kubernetes solution.


Monitoring with Prometheus
---------------------------

This section is to be added in the near future


Maintaining and Restoring Backups
---------------------------------

This section is to be added in the near future