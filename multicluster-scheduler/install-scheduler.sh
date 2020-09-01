export CLUSTER1=private-hybrid
export CLUSTER2=public-hybrid 
export NAMESPACE=default 

##install cetmanager
helm repo add jetstack https://charts.jetstack.io
helm repo update

for CONTEXT in $CLUSTER1 $CLUSTER2
do
  kubectl --context $CONTEXT apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml
  kubectl --context $CONTEXT create namespace cert-manager
  helm install cert-manager jetstack/cert-manager \
    --kube-context $CONTEXT \
    --namespace cert-manager \
    --version v0.12.0 \
    --wait
done



## instal multicluster scheduler
helm repo add admiralty https://charts.admiralty.io
helm repo update

for CONTEXT in $CLUSTER1 $CLUSTER2
do
  kubectl --context "$CONTEXT" create namespace admiralty
  helm install multicluster-scheduler admiralty/multicluster-scheduler \
    --kube-context "$CONTEXT" \
    --namespace admiralty \
    --version 0.10.0 \
    --wait
done

##create source for cluster 1 in cluster 2
cat <<EOF | kubectl --context "$CLUSTER2" apply -f -
apiVersion: multicluster.admiralty.io/v1alpha1
kind: Source
metadata:
  name: c1
  namespace: $NAMESPACE
spec:
  serviceAccountName: c1
EOF

## ecport secret for cluster 1 from cluster 2
kubemcsa export --context "$CLUSTER2" -n "$NAMESPACE" c1 --as c2 \
  | kubectl --context "$CLUSTER1" -n "$NAMESPACE" apply -f -

# create cluster targets for c1(self) and c2 in cluster 1

cat <<EOF | kubectl --context "$CLUSTER1" apply -f -
apiVersion: multicluster.admiralty.io/v1alpha1
kind: Target
metadata:
  name: c2
  namespace: $NAMESPACE
spec:
  kubeconfigSecret:
    name: c2
---
apiVersion: multicluster.admiralty.io/v1alpha1
kind: Target
metadata:
  name: c1
  namespace: $NAMESPACE
spec:
  self: true
EOF

#After a minute, check that virtual nodes named admiralty-namespace-$NAMESPACE-c1 and admiralty-namespace-$NAMESPACE-c2 have been created in cluster1:

kubectl --context "$CLUSTER1" get node -l virtual-kubelet.io/provider=admiralty

