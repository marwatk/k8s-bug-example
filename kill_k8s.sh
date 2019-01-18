#!/bin/bash

set -e

NAMESPACE=kill-vpnkit
LOOP_COUNT=0

while true; do
  ((++LOOP_COUNT))
  echo "Loop count: $LOOP_COUNT"
  kubectl version

  set +e
  kubectl delete namespace $NAMESPACE > /dev/null 2>&1
  kubectl delete pv $NAMESPACE-pv > /dev/null 2>&1
  set -e

  NAMESPACE_COUNT=0
  while kubectl get namespace $NAMESPACE > /dev/null 2>&1; do
    ((++NAMESPACE_COUNT))
    echo "Waiting for namespace to delete ($NAMESPACE_COUNT)"
    if [ "$NAMESPACE_COUNT" == 30 ]; then
      echo "Namespace never deleted"
      exit 1
    fi
    sleep 1
  done


  kubectl create -f - <<EOF
    kind: Namespace
    apiVersion: v1
    metadata:
      name: $NAMESPACE
      labels:
        name: $NAMESPACE
EOF

  kubectl create -n $NAMESPACE -f - <<EOF
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

  kubectl create -n $NAMESPACE -f - <<EOF
      apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: test-pvc
        labels:
          name: test-pvc
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 100Mi
        storageClassName: hostpath
EOF


    kubectl create -f - <<EOF
      apiVersion: v1
      kind: PersistentVolume
      metadata:
        name: "$NAMESPACE-pv"
      spec:
        accessModes:
        - ReadWriteOnce
        capacity:
          storage: 100Mi
        hostPath:
          path: "/tmp"
          type: DirectoryOrCreate
        persistentVolumeReclaimPolicy: Delete
        storageClassName: hostpath
EOF

    kubectl create -n $NAMESPACE -f - <<EOF
      kind: ConfigMap
      apiVersion: v1
      metadata:
        name: test-config
      data:
        foo: SGVsbG8gd29ybGQ=
EOF

    kubectl create -n $NAMESPACE -f - <<EOF
      kind: Secret
      apiVersion: v1
      metadata:
        name: test-secret
      data:
        foo: SGVsbG8gd29ybGQ=
EOF

  POD_COUNT=0
  while true; do
    ((++POD_COUNT))
    echo -n "[$POD_COUNT] pod foo-deployment: "

    set +e
    PHASE=$(kubectl -n $NAMESPACE get pod -l "app=nginx" -o "jsonpath={.items[0].status.phase}")
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
  kubectl delete namespace $NAMESPACE > /dev/null 2>&1
  kubectl delete pv $NAMESPACE-pv > /dev/null 2>&1
  set -e

done