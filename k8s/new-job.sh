#!/bin/bash

export SUFFIX=$(head /dev/urandom | tr -dc a-z0-9 | head -c 4)

cat <<EOF | kubectl  apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  labels:
    app: mnist-ml
  name: ml-job-${SUFFIX}
spec:
  parallelism: 1
  template:
    metadata:
      annotations:
        multicluster.admiralty.io/elect: ""
      labels:
        app: mnist-ml
    spec:
      containers:
      - env:
        - name: AZURE_STORAGE_CONNECTION_STRING
          value: DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://blob-storage:10000/devstoreaccount1;
        - name: EPOCHS
          value: "1"
        - name: JOB_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: ISTIO
          value: "true"
        image: smennig/ml-job:mnist
        imagePullPolicy: Always
        name: ml-job
        ports:
          - containerPort: 8080
            protocol: TCP
        resources:
          limits:
            cpu: "1"
            memory: 1000Mi
          requests:
            cpu: 100m
            memory: 200Mi
      restartPolicy: Never
      dnsPolicy: ClusterFirst
      # nodeSelector:
      #   topology.kubernetes.io/region: westus
EOF

