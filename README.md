[![Build Status](https://travis-ci.org/IBM/OpenWhisk-on-Kubernetes.svg?branch=master)](https://travis-ci.org/IBM/OpenWhisk-on-Kubernetes)

# OpenWhisk on Kubernetes leveraging Bluemix Container Service

This code demonstrates the deployment of OpenWhisk on Kubernetes cluster. Apache OpenWhisk is a serverless, open source cloud platform that executes functions in response to events at any scale. As a developer, there's no need to manage the servers that run your code. Apache OpenWhisk operates and scales your application for you. 

With IBM Bluemix Container Service, you can deploy and manage your own Kubernetes cluster in the cloud that lets you automate the deployment, operation, scaling, and monitoring of containerized apps over a cluster of independent compute hosts called worker nodes.  We can then leverage Bluemix Container Service using Kubernetes to deploy scalable OpenWhisk.

![kube-openwhisk](images/kube-openwhisk.png)

## Included Components
- [OpenWhisk](http://openwhisk.org/)
- [Kubernetes Clusters](https://console.ng.bluemix.net/docs/containers/cs_ov.html#cs_ov)
- [Bluemix container service](https://console.ng.bluemix.net/catalog/?taxonomyNavigation=apps&category=containers)
- [Bluemix DevOps Toolchain Service](https://console.ng.bluemix.net/catalog/services/continuous-delivery)

## Kubernetes Concepts Used

- [Kubenetes Pods](https://kubernetes.io/docs/user-guide/pods)
- [Kubenetes Services](https://kubernetes.io/docs/user-guide/services)
- [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/)
- [Kubernets StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

## Prerequisites

- Install [OpenWhisk CLI](https://console.ng.bluemix.net/openwhisk/learn/cli)

- Create a Kubernetes cluster with [IBM Bluemix Container Service](https://github.com/IBM/container-journey-template) to deploy on the cloud. The code here is regularly tested against [Kubernetes Cluster from Bluemix Container Service](https://console.ng.bluemix.net/docs/containers/cs_ov.html#cs_ov) using Travis.

## Deploy to Bluemix
If you want to deploy OpenWhisk directly to Kubernetes cluster on Bluemix, click on 'Deploy to Bluemix' button below to create a Bluemix DevOps service toolchain and fill in all the environment variables on **Delivery Pipeline**. For Further instructions, please follow the [Toolchain instructions](https://github.com/IBM/container-journey-template/blob/master/Toolchain_Instructions_new.md).

> You will need to create your Kubernetes cluster first and make sure it is fully deployed in your Bluemix account.

[![Create Toolchain](https://github.com/IBM/container-journey-template/blob/master/images/button.png)](https://console.ng.bluemix.net/devops/setup/deploy/)


The OpenWhisk will not be exposed on the public IP of the Kubernetes cluster. You can still access them by exporting your Kubernetes cluster configuration using `bx cs cluster-config <your-cluster-name>` and doing [Step 5](#5-build-or-use-openwhisk-docker-images) or to simply check their status `kubectl exec <POD-NAME> -- nodetool status`

## Steps

1. [Download OpenWhisk-Kubernetes codebase](#1-download-openwhisk-kubernetes-codebase)

### Quick Start

2. [Create OpenWhisk namespace](#2-create-openwhisk-namespace)
3. [Run Kubernetes Job to deploy OpenWhisk](#3-run-kubernetes-job-to-deploy-openwhisk)

### Manually deploying
4. [Create Kubernetes yaml files](#4-create-kubernetes-yaml-files)
5. [Build or use OpenWhisk Docker Images](#5-build-or-use-openwhisk-docker-images)
6. [Deploy OpenWhisk on Kubernetes](#6-deploy-openwhisk-on-kubernetes)

[Troubleshooting](#troubleshooting)


# 1. Download OpenWhisk Kubernetes codebase
Download the code needed to build and deploy OpenWhisk on Kubernetes

```
git clone https://github.com/apache/incubator-openwhisk-deploy-kube.git
cd incubator-openwhisk-deploy-kube
```

# 2. Create OpenWhisk namespace

Once you are successfully targeted, you will need to create a create a namespace called openwhisk. To do this, you can just run the following command.

```
kubectl apply -f configure/openwhisk_kube_namespace.yml
```

# 3. Run Kubernetes Job to deploy OpenWhisk

>**Important**: Since the Kubernetes Job needs the cluster-admin role to create and deploy all the necessary components for OpenWhish, please run `kubectl get ClusterRole` and make sure you have **cluster-admin** role in order to proceed to the following steps. If you do not have a cluster-admin role, please switch to a cluster that has a cluster-admin role.

First, we need to change a Cluster Role Binding to give permission for the job to run on Bluemix Kubernetes clusters. So, create a `permission.yaml` file with the following code (Or you can clone it from our repository `git clone https://github.com/IBM/OpenWhisk-on-Kubernetes.git.git`).

```yaml
apiVersion: rbac.authorization.k8s.io/v1alpha1
kind: ClusterRoleBinding
metadata:
  name: openwhisk:admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: default
  namespace: openwhisk
```

Then, run the ClusterRoleBinding on your Kubernetes.

```
kubectl create -f permission.yaml
```

Now, run the Kubernetes job to setup the OpenWhisk environment.

```
kubectl apply -f configure/configure_whisk.yml
```
The Kubernetes job under the covers pulls the latest Docker image needed as a base and runs the configuration script

To see what is happening during the deployment process, you should be able to see the logs by running

```
kubectl -n openwhisk get pods #This will retrieve which pod is running the configure-openwhisk
kubectl -n openwhisk logs configure-openwhisk-XXXXX
```

As part of the deployment process, we store the OpenWhisk Authorization tokens in Kubernetes secrets. To use the secrets you will need to base64 decode them. So, run the following commands to retrieve your secret and decode it with base64.

```
export AUTH_SECRET=$(kubectl -n openwhisk get secret openwhisk-auth-tokens -o yaml | grep 'auth_whisk_system:' | awk '{print $2}' | base64 --decode)
```

Obtain the IP address of the Kubernetes nodes. You will need this to setup your OpenWhisk API host.

```
kubectl get nodes
```

Obtain the public port for the Kubernetes Nginx Service and note the port that used for the API endpoint.

```
export WSK_PORT=$(kubectl -n openwhisk describe service nginx | grep https-api | grep NodePort| awk '{print $3}' | cut -d'/' -f1)
```
Now you should be able to setup the wsk cli like normal and interact with Openwhisk.

```
export KUBE_IP=$(kubectl get nodes | grep Ready | awk '{ print $1;exit }')
wsk property set --auth $AUTH_SECRET --apihost https://$KUBE_IP:$WSK_PORT
wsk -i action invoke /whisk.system/utils/echo -p message hello --blocking --result 
```
> Note: Since your Kubernetes doesn't contain any IP SANs, you need to run your OpenWhisk actions with the insecure `-i` flag.

# 4. Create Kubernetes yaml files

The current Kube Deployment and Services files that define the OpenWhisk
cluster can be found [here](https://github.com/apache/incubator-openwhisk-deploy-kube/tree/master/ansible-kube/environments/kube/files). Only one
instance of each OpenWhisk process is created, but if you would like
to increase that number, then this would be the place to do it. Simply edit
the appropriate file and
[Manually Build Custom Docker Files](#5-build-or-use-openwhisk-docker-images)

# 5. Build or use OpenWhisk Docker Images

There are two images that are required when deploying OpenWhisk on Kube,
Nginx and the OpenWhisk configuration image.

To build these images, there is a helper script to build the
required dependencies and build the Docker images itself. For example,
the wsk cli is built locally and then copied into these images.

The script takes 2 arguments:
1. (Required) The first argument is the Docker account to push the built images
   to. For Nginx, it will tag the image as `account_name/whisk_nginx:latest`
   and the OpenWhisk configuration image will be tagged `account_name/whisk_config:dev`.

   NOTE:  **log into Docker** before running the script or it will
   fail to properly upload the docker images.

2. The second argument is the location of where the
   [OpenWhisk](https://github.com/apache/incubator-openwhisk) repo is installed
   locally. By default, it assumes that this repo exists at
   `$HOME/workspace/openwhisk`. If you don't have OpenWhisk installed locally,
   you can run `git clone https://github.com/apache/incubator-openwhisk.git` to clone the openwhisk directory.

If you plan on building your own images and would like to change from `danlavine's`,
then make sure to update the
[configure_whisk.yml](https://github.com/apache/incubator-openwhisk-deploy-kube/blob/master/configure/configure_whisk.yml) and
[nginx](https://github.com/apache/incubator-openwhisk-deploy-kube/blob/master/ansible-kube/environments/kube/files/nginx.yml) with your images.

To run the script, use the command:

```
./docker/build.sh <docker username> <full path of openwhisk dir>
```

Now, you can view your images locally or on DockerHub.


# 6. Deploy OpenWhisk on Kubernetes

When in the process of creating a new deployment, it is nice to
run things by hand to see what is going on inside the container and
not have it be removed as soon as it finishes or fails. For this,
you can change the command of [configure_whisk.yml](https://github.com/apache/incubator-openwhisk-deploy-kube/blob/master/configure/configure_whisk.yml)
to `command: [ "tail", "-f", "/dev/null" ]`. Then just run the
original command from inside the Pod's container.

To create and get inside the pod, run

```bash
kubectl apply -f configure/openwhisk_kube_namespace.yml
kubectl apply -f configure/configure_whisk.yml
kubectl -n openwhisk get pods #This will retrieve which pod is running the configure-openwhisk
kubectl -n openwhisk exec -it configure-openwhisk-XXXXX /bin/bash
```

> Note: If you don't have permission to deploy your services/pods, please go to [Troubleshooting](#troubleshooting) to add permission to your namespace.

## Troubleshooting

As part of the development process, you might need to clean up the Kubernetes
environment at some point. For this, we want to delete all the Kube deployments,
services and jobs. For this, you can run the following commands:

```
kubectl delete pods,deployments,configmaps,statefulsets,services,jobs --all --namespace=openwhisk
kubectl delete namespace openwhisk
```

If your job doesn't have permission to create new deployments/services, we need to change a Cluster Role Binding to give permission for the job to run on Bluemix Kubernetes clusters. Therefore, create a `permission.yaml` file with the following code (Or you can clone it from our repository `git clone https://github.com/IBM/openwhisk-on-k8.git`).

  >**Important**: Since the Kubernetes Job needs the cluster-admin role to create and deploy all the necessary components for OpenWhish, please run `kubectl get ClusterRole` and make sure you have **cluster-admin** role in order to proceed to the following steps. If you do not have a cluster-admin role, please switch to a cluster that has a cluster-admin role.

  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1alpha1
  kind: ClusterRoleBinding
  metadata:
    name: openwhisk:admin
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: cluster-admin
  subjects:
  - kind: ServiceAccount
    name: default
    namespace: openwhisk
  ```

  Then, run the ClusterRoleBinding on your Kubernetes.

  ```
  kubectl create -f permission.yaml
  ```

## License

[Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0)
