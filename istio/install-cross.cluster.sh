
export MAIN_CLUSTER_CTX=private-hybrid
export REMOTE_CLUSTER_CTX=public-hybrid
export ISTIO_SAMPLE_PATH=./samples

# createcommon certs
kubectl create namespace istio-system --context=${MAIN_CLUSTER_CTX}
kubectl --context=${MAIN_CLUSTER_CTX} create secret generic cacerts -n istio-system \
    --from-file=${ISTIO_SAMPLE_PATH}/certs/ca-cert.pem \
    --from-file=${ISTIO_SAMPLE_PATH}/certs/ca-key.pem \
    --from-file=${ISTIO_SAMPLE_PATH}/certs/root-cert.pem \
    --from-file=${ISTIO_SAMPLE_PATH}/certs/cert-chain.pem

kubectl create namespace istio-system --context=${REMOTE_CLUSTER_CTX}
kubectl --context=${REMOTE_CLUSTER_CTX} create secret generic cacerts -n istio-system \
    --from-file=${ISTIO_SAMPLE_PATH}/certs/ca-cert.pem \
    --from-file=${ISTIO_SAMPLE_PATH}/certs/ca-key.pem \
    --from-file=${ISTIO_SAMPLE_PATH}/certs/root-cert.pem \
    --from-file=${ISTIO_SAMPLE_PATH}/certs/cert-chain.pem


export MAIN_CLUSTER_NAME=main0
export REMOTE_CLUSTER_NAME=remote0


export MAIN_CLUSTER_NETWORK=network1
export REMOTE_CLUSTER_NETWORK=network2

cat <<EOF> istio-main-cluster.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enablePrometheusMerge: false
  values:
    prometheus:
      enabled: false
    global:
      multiCluster:
        clusterName: ${MAIN_CLUSTER_NAME}
      network: ${MAIN_CLUSTER_NETWORK}

      # Mesh network configuration. This is optional and may be omitted if
      # all clusters are on the same network.
      meshNetworks:
        ${MAIN_CLUSTER_NETWORK}:
          endpoints:
          - fromRegistry:  ${MAIN_CLUSTER_NAME}
          gateways:
          - registry_service_name: istio-ingressgateway.istio-system.svc.cluster.local
            port: 443

        ${REMOTE_CLUSTER_NETWORK}:
          endpoints:
          - fromRegistry: ${REMOTE_CLUSTER_NAME}
          gateways:
          - registry_service_name: istio-ingressgateway.istio-system.svc.cluster.local
            port: 443

      # Use the existing istio-ingressgateway.
      meshExpansion:
        enabled: true
EOF

istioctl install -f istio-main-cluster.yaml --context=${MAIN_CLUSTER_CTX}

#should be running
kubectl get pod -n istio-system --context=${MAIN_CLUSTER_CTX}

#detrimine ip
export ISTIOD_REMOTE_EP=$(kubectl get svc -n istio-system --context=${MAIN_CLUSTER_CTX} istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "ISTIOD_REMOTE_EP is ${ISTIOD_REMOTE_EP}"

remote cluster 
cat <<EOF> istio-remote0-cluster.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      # The remote cluster's name and network name must match the values specified in the
      # mesh network configuration of the primary cluster.
      multiCluster:
        clusterName: ${REMOTE_CLUSTER_NAME}
      network: ${REMOTE_CLUSTER_NETWORK}

      # Replace ISTIOD_REMOTE_EP with the the value of ISTIOD_REMOTE_EP set earlier.
      remotePilotAddress: ${ISTIOD_REMOTE_EP}

  ## The istio-ingressgateway is not required in the remote cluster if both clusters are on
  ## the same network. To disable the istio-ingressgateway component, uncomment the lines below.
  #
  # components:
  #  ingressGateways:
  #  - name: istio-ingressgateway
  #    enabled: false
EOF

# apply the remote cluster configuration
istioctl install -f istio-remote0-cluster.yaml --context ${REMOTE_CLUSTER_CTX}

#wait for the cluster to be ready
kubectl get pod -n istio-system --context=${REMOTE_CLUSTER_CTX}


#apply to both clutsters
cat <<EOF> cluster-aware-gateway.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: cluster-aware-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: tls
      protocol: TLS
    tls:
      mode: AUTO_PASSTHROUGH
    hosts:
    - "*.local"
EOF


kubectl apply -f cluster-aware-gateway.yaml --context=${MAIN_CLUSTER_CTX}
kubectl apply -f cluster-aware-gateway.yaml --context=${REMOTE_CLUSTER_CTX}


# create secrets for the remote cluster
istioctl x create-remote-secret --name ${REMOTE_CLUSTER_NAME} --context=${REMOTE_CLUSTER_CTX} | \
    kubectl apply -f - --context=${MAIN_CLUSTER_CTX}

