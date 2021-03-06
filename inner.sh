#!/bin/bash

set -e

NAMESPACE=k8s-bug-inner
KUBE_ARGS="--certificate-authority /run/secrets/kubernetes.io/serviceaccount/ca.crt --token $(cat /run/secrets/kubernetes.io/serviceaccount/token) --server https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT_HTTPS"

LOOP_COUNT=0

while true; do
  ((++LOOP_COUNT))
  echo "Loop count: $LOOP_COUNT"
  kubectl version

  set +e
  kubectl $KUBE_ARGS delete namespace $NAMESPACE > /dev/null 2>&1
  set -e

  NAMESPACE_COUNT=0
  while kubectl $KUBE_ARGS get namespace $NAMESPACE > /dev/null 2>&1; do
    ((++NAMESPACE_COUNT))
    echo "Waiting for namespace to delete ($NAMESPACE_COUNT)"
    if [ "$NAMESPACE_COUNT" == 30 ]; then
      echo "Namespace never deleted"
      exit 1
    fi
    sleep 1
  done

  if [ "$LOOP_COUNT" == 2 ]; then
    echo "Inner test finished"
    exit 0
  fi

  kubectl $KUBE_ARGS create -f - <<EOF
    kind: Namespace
    apiVersion: v1
    metadata:
      name: $NAMESPACE
      labels:
        name: $NAMESPACE
EOF

  kubectl $KUBE_ARGS create -n $NAMESPACE -f - <<EOF
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: nginx-deployment
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: nginx
      template:
        metadata:
          labels:
            app: nginx
        spec:
          containers:
          - name: nginx
            image: nginx:1.7.9
            ports:
            - containerPort: 80
EOF


  POD_COUNT=0
  while true; do
    ((++POD_COUNT))
    echo -n "[$POD_COUNT] pod foo-deployment: "

    set +e
    PHASE=$(kubectl $KUBE_ARGS -n $NAMESPACE get pod -l "app=nginx" -o "jsonpath={.items[0].status.phase}")
    set -e
    if [ "$?" == "0" ]; then
      echo "Phase is [$PHASE]"
      if [ "$PHASE" == "Running" ]; then
        break;
      fi
    else 
      echo "Phase is missing"
    fi

    if [ "$POD_COUNT" == 20 ]; then
      echo "Pod never got created"
      exit 1
    fi

    sleep 1
  done

  set +e
  echo "Deleting namespace"
  kubectl $KUBE_ARGS delete namespace $NAMESPACE > /dev/null 2>&1
  set -e

done