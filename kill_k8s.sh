#!/bin/bash

set -e

LOOP_COUNT=0

while true; do
  ((++LOOP_COUNT))
  echo "Loop count: $LOOP_COUNT"
  kubectl version

  set +e
  kubectl delete namespace eventually-fail
  set -e

  NAMESPACE_COUNT=0
  while kubectl get namespace eventually-fail > /dev/null 2>&1; do
    ((++NAMESPACE_COUNT))
    echo "Waiting for namespace to delete ($NAMESPACE_COUNT)"
    if [ "$NAMESPACE_COUNT" == 20 ]; then
      echo "Namespace never deleted"
      exit 1
    fi
    sleep 1
  done


  kubectl create -f - <<EOF
kind: Namespace
apiVersion: v1
metadata:
  name: eventually-fail
  labels:
    name: eventually-fail
EOF

    kubectl create -n eventually-fail -f - <<EOF
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
    PHASE=$(kubectl -n eventually-fail get pod -l "app=nginx" -o "jsonpath={.items[0].status.phase}")
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

done