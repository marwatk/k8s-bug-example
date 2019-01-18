#!/bin/bash

set -e

OUTER_NAMESPACE=k8s-bug-outer
docker build . -t kill-vpnkit

set +e
kubectl delete namespace $OUTER_NAMESPACE >/dev/null 2>&1
set -e

NAMESPACE_COUNT=0
while kubectl get namespace $OUTER_NAMESPACE > /dev/null 2>&1; do
  ((++NAMESPACE_COUNT))
  echo "Waiting for namespace to delete ($NAMESPACE_COUNT)"
  if [ "$NAMESPACE_COUNT" == 30 ]; then
    echo "Namespace never deleted"
    exit 1
  fi
  sleep 1
done

kubectl create namespace $OUTER_NAMESPACE

kubectl -n $OUTER_NAMESPACE run kill-vpnkit -it --image kill-vpnkit --restart Never --command -- sh /usr/local/bin/kill_k8s.sh