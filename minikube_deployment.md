# Deploy OpenWhisk on Minikube

## Prerequisites
- Install [OpenWhisk CLI](https://console.ng.bluemix.net/openwhisk/learn/cli)
- Set up your [Minikube](https://github.com/kubernetes/minikube) before proceeding to the following steps.

## Steps

1. [Download OpenWhisk-Kubernetes codebase](#1-download-openwhisk-kubernetes-codebase)
2. [Create OpenWhisk namespace](#2-create-openwhisk-namespace)
3. [Run Kubernetes Job to deploy OpenWhisk](#3-run-kubernetes-job-to-deploy-openwhisk)

# 1. Download OpenWhisk Kubernetes codebase
Download the code needed to build and deploy OpenWhisk on Kubernetes

```bash
git clone https://github.com/apache/incubator-openwhisk-deploy-kube.git
cd incubator-openwhisk-deploy-kube
```

# 2. Create OpenWhisk namespace

Once you are successfully targeted, you will need to create a create a namespace called openwhisk. To do this, you can just run the following command.

```bash
kubectl apply -f configure/openwhisk_kube_namespace.yml
```

# 3. Run Kubernetes Job to deploy OpenWhisk

Since Minikube only support Docker API version 1.23, we want to deploy some of our components with a lower version of Docker. 
To do this, we want to run the deployment script manually by changing the command of [configure_whisk.yml](https://github.com/apache/incubator-openwhisk-deploy-kube/blob/master/configure/configure_whisk.yml)
to `command: [ "tail", "-f", "/dev/null" ]`. 

Now, run and configure the Kubernetes job to setup the OpenWhisk environment.

```bash
kubectl apply -f configure/configure_whisk.yml
kubectl -n openwhisk get pods #Look for your configure-openwhisk's pod name
kubectl -n openwhisk exec -ti configure-openwhisk-XXXXX /bin/bash #Replace configure-openwhisk-XXXXX to your configure-openwhisk's pod name
```

Now, you are inside the configure-openwhisk pod. Run the following command to edit the Docker API version for one of our components.

```bash
sed '/"15s"/a "         - name: "DOCKER_API_VERSION" \n            value: "1.23"' /incubator-openwhisk-deploy-kube/ansible-kube/environments/kube/files/invoker.yml
```

Then, in your configure-openwhisk pod, run the configure script to deploy OpenWhisk

```bash
./incubator-openwhisk-deploy-kube/configure/configure.sh
```

After the configure.sh script is successfully executed, exit the pod by running `exit`. Now, you should see the following pods if your OpenWhisk is successfully deployed.

```bash
$ kubectl -n openwhisk get pods --show-all=true
NAME                          READY     STATUS      RESTARTS   AGE
configure-openwhisk-102nl     1/1       Running     0          7d
consul-57995027-17l71         2/2       Running     0          7d
controller-4190656464-v86b7   1/1       Running     0          7d
couchdb-109298327-4v0gz       1/1       Running     0          7d
invoker-0                     1/1       Running     0          7d
kafka-1060962555-hxqlj        1/1       Running     0          7d
nginx-1175504326-v8qk4        1/1       Running     0          7d
zookeeper-1304892743-q8drf    1/1       Running     0          7d
```

Next, We need to enable Promiscuous mode for your *docker0* network, so you can access OpenWhisk on your local machine.

```bash
minikube ssh
ip link set docker0 promisc on
exit
```

Now you should be able to setup the wsk cli like normal and interact with Openwhisk. let's set up your OpenWhisk Endpoint on your Openwhisk CLI.

```bash
export AUTH_SECRET=$(kubectl -n openwhisk get secret openwhisk-auth-tokens -o yaml | awk ' /auth_whisk_system/ {print $2}' | base64 --decode)
export WSK_PORT=$(kubectl -n openwhisk describe service nginx | awk ' /https-api/ && /NodePort/ {print substr($3,0,5)}')
export KUBE_IP=$(minikube -n openwhisk service nginx --url | awk '{print substr($1,8,14);exit}')
wsk property set --auth $AUTH_SECRET --apihost https://$KUBE_IP:$WSK_PORT
```
Congratulation, your OpenWhisk is up and running on your Minikube. Here's a simple command that helps your start testing your OpenWhisk.

```bash
$ wsk -i action invoke /whisk.system/utils/echo -p message hello --blocking --result 
{
    "message": "hello"
}
```
> Note: Since your Kubernetes doesn't contain any IP SANs, you need to run your OpenWhisk actions with the insecure `-i` flag.

