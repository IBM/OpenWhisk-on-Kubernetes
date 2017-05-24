#!/bin/bash

echo "Create OpenWhisk"
IP_ADDR=$(bx cs workers $CLUSTER_NAME | grep Ready | awk '{ print $2 }')
if [ -z $IP_ADDR ]; then
  echo "$CLUSTER_NAME not created or workers not ready"
  exit 1
fi

echo -e "Configuring vars"
exp=$(bx cs cluster-config $CLUSTER_NAME | grep export)
if [ $? -ne 0 ]; then
  echo "Cluster $CLUSTER_NAME not created or not ready."
  exit 1
fi
eval "$exp"

echo -e "Deleting previous version of OpenWhisk if it exists"
kubectl delete --ignore-not-found=true pods,deployments,configmaps,statefulsets,services,jobs --all --namespace=openwhisk
kubectl delete --ignore-not-found=true namespace openwhisk

kubectl create -f permission.yaml

#Clone the repo
git clone https://github.com/apache/incubator-openwhisk-deploy-kube.git
cd incubator-openwhisk-deploy-kube

#Create namespace and config script
kubectl apply -f configure/openwhisk_kube_namespace.yml
sed -i s#openwhisk-devtools/kubernetes#incubator-openwhisk-deploy-kube# configure/configure_whisk.yml
kubectl apply -f configure/configure_whisk.yml

echo "Wait until configure_whisk is finish, usually takes 15 minutes."
whisk=$(kubectl -n openwhisk get pods | grep "configure-openwhisk")
while [ ${#kuber} -ne 0 ]; do
	echo "Wait until configure_whisk is finish"
	sleep 120s
	whisk=$(kubectl -n openwhisk get pods | grep "configure-openwhisk")
done

#Get credentials from our kubernetes openwhisk.
kubectl -n openwhisk get secret openwhisk-auth-tokens -o yaml
export AUTH_SECRET=$(kubectl -n openwhisk get secret openwhisk-auth-tokens -o yaml | grep 'auth_whisk_system:' | awk '{print $2}' | base64 --decode)
export WSK_PORT=$(kubectl -n openwhisk describe service nginx | grep https-api | grep NodePort| awk '{print $3}' | cut -d'/' -f1)

echo "Your OpenWhisk is deployed on your Kubernetes Cluster, run the below command to setup your openwhisk endpoint." 
echo "wsk property set --auth $AUTH_SECRET --apihost https://$IP_ADDR:$WSK_PORT"

echo "" && echo "You can run the following command to test your OpenWhisk." 
echo "wsk -i action invoke /whisk.system/utils/echo -p message hello --blocking --result"