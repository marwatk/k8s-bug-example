#!/bin/bash

set -e

OUTER_NAMESPACE=k8s-bug-outer
IMAGE_NAME=k8s-bug
docker build . -t $IMAGE_NAME

OUTER_LOOP=0
while true; do
  ((++OUTER_LOOP))
  echo "Outer loop: $OUTER_LOOP"
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

  kubectl -n $OUTER_NAMESPACE run $IMAGE_NAME -it --image $IMAGE_NAME --restart Never --command -- sh /usr/local/bin/inner.sh

  set +e
  kubectl delete namespace $OUTER_NAMESPACE >/dev/null 2>&1
  set -e
done