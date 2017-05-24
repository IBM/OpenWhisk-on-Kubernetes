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

git clone https://github.com/openwhisk/openwhisk-devtools.git
cd openwhisk-devtools/kubernetes

kubectl apply -f configure/openwhisk_kube_namespace.yml
sed -i s#openwhisk-devtools/kubernetes#incubator-openwhisk-deploy-kube# configure/configure_whisk.yml
kubectl apply -f configure/configure_whisk.yml

#sleep until configure_whisk is finish.
sleep 5m

kubectl -n openwhisk get secret openwhisk-auth-tokens -o yaml
export AUTH_SECRET=$(kubectl -n openwhisk get secret openwhisk-auth-tokens -o yaml | grep 'auth_whisk_system:' | awk '{print $2}' | base64 --decode)
export WSK_PORT=$(kubectl -n openwhisk describe service nginx | grep https-api | grep NodePort| awk '{print $3}' | cut -d'/' -f1)

echo "Your OpenWhisk is deployed on your Kubernetes Cluster, run the below command to setup your openwhisk endpoint." 
echo "wsk property set --auth $AUTH_SECRET --apihost https://$IP_ADDR:$WSK_PORT"

echo "" && echo "You can run the following command to test your OpenWhisk." 
echo "wsk -i action invoke /whisk.system/utils/echo -p message hello --blocking --result"