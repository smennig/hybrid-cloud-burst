# hybrid-cloud-burst

Example porject to showcase cloud bursting with kubernetes.

# Setup
2 kubernetes cluster are needed with the following components installed.


- istio mulicluster installation with a shared control plane: https://istio.io/latest/docs/setup/install/multicluster/shared/ 
- kubernetes cluster federation:
https://github.com/kubernetes-sigs/kubefed/blob/master/docs/userguide.md
- admiralty.io multicluster scheduler:
https://github.com/admiraltyio/multicluster-scheduler/tree/master

The installation instructions for each project are easy to follow, but you can find the steps I use to setup in `./istio` and `./mulicluster-scheduler`.

#  Deploy the sample App
Create the namespace:
```
$ kubectl --context ${MAIN_CLUSTER_CTX} apply -f k8s/namespace.yaml
```
Create the service and the deployment for the blob storage. Note they use kubernetes federation. Make sure to ajust the cluster-name in `k8s/blob-storage.yaml` to match your cluster.

```
$ kubectl --context ${MAIN_CLUSTER_CTX} apply -f k8s/blob-storage.yaml
$ kubectl --context ${MAIN_CLUSTER_CTX} apply -f k8s/blob-storage-service.yaml
```
Your deployment should look something like this:

Main cluster:
```
$ kubectl --context ${MAIN_CLUSTER_CTX} get all 
NAME                               READY   STATUS    RESTARTS   AGE
pod/blob-storage-d4556c66f-z79f2   2/2     Running   0          2d5h

NAME                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)     AGE
service/blob-storage   ClusterIP   10.0.225.183   <none>        10000/TCP   3d6h
service/kubernetes     ClusterIP   10.0.0.1       <none>        443/TCP     5d23h

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/blob-storage   1/1     1            1           3d5h

NAME                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/blob-storage-d4556c66f   1         1         1       3d5h
```
Remote cluster:
```
$ kubectl --context ${REMOTE_CLUSTER_CTX} get all 
NAME                   TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)     AGE
service/blob-storage   ClusterIP   10.0.42.74   <none>        10000/TCP   3d6h
service/kubernetes     ClusterIP   10.0.0.1     <none>        443/TCP     7d6h
```

Create a new machine learing job, which will be automatically scheduled in one cluster. 

```
$ ./new-job.s
job.batch/ml-job-6ymu created
```

Check which cluster is running the pod:
```
$ kubectl --context ${MAIN_CLUSTER_CTX} get pods
NAME                           READY   STATUS      RESTARTS   AGE
blob-storage-d4556c66f-z79f2   2/2     Running     0          2d5h
ml-job-6ymu-xvrv2              2/2     Running   0          20

$ kubectl --context ${REMOTE_CLUSTER_CTX} get pods
NAME                      READY   STATUS    RESTARTS   AGE
ml-job-6ymu-xvrv2-p5bbl   2/2     Running   0          27s
```
The MAIN_CLUSTER_CTX is only running the proxy pod in this case. The delegate pod is executed in the REMOTE_CLUSTER_CTX.

# Overview of the sample App

The sampel app is training a neural network with a python script and uploads the trained model to the blob-storage. 
The training data is the popular MNIST dataset of handwritten digits http://yann.lecun.com/exdb/mnist/. 