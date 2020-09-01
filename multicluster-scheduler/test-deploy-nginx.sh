export CLUSTER1=private-hybrid
export CLUSTER2=public-hybrid 
export NAMESPACE=default 

cat <<EOF | kubectl --context "$CLUSTER1" -n "$NAMESPACE" apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 5
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
      annotations:
        multicluster.admiralty.io/elect: ""
    spec:
      containers:
      - name: nginx
        image: nginx
        resources:
          requests:
            cpu: 100m
            memory: 32Mi
        ports:
        - containerPort: 80
EOF


# kubectl --context "$CLUSTER1" -n "$NAMESPACE" patch deployment nginx -p '{
#   "spec":{
#     "template":{
#       "spec": {
#         "nodeSelector": {
#           "topology.kubernetes.io/region": "westus"
#         }
#       }
#     }
#   }
# }'