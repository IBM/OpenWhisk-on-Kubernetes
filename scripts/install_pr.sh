# This Travis script is from the original OpenWhisk repo at https://github.com/apache/incubator-openwhisk-deploy-kube

echo "Cloning OpenWhisk Repository"
git clone https://github.com/apache/incubator-openwhisk-deploy-kube.git
cd incubator-openwhisk-deploy-kube


# This script assumes Docker is already installed
#!/bin/bash

set -x

# set docker0 to promiscuous mode
sudo ip link set docker0 promisc on

# install etcd
wget https://github.com/coreos/etcd/releases/download/$TRAVIS_ETCD_VERSION/etcd-$TRAVIS_ETCD_VERSION-linux-amd64.tar.gz
tar xzf etcd-$TRAVIS_ETCD_VERSION-linux-amd64.tar.gz
sudo mv etcd-$TRAVIS_ETCD_VERSION-linux-amd64/etcd /usr/local/bin/etcd
rm etcd-$TRAVIS_ETCD_VERSION-linux-amd64.tar.gz
rm -rf etcd-$TRAVIS_ETCD_VERSION-linux-amd64

# download kubectl
wget https://storage.googleapis.com/kubernetes-release/release/$TRAVIS_KUBE_VERSION/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

# download kubernetes
git clone https://github.com/kubernetes/kubernetes $HOME/kubernetes

# install cfssl
go get -u github.com/cloudflare/cfssl/cmd/...

pushd $HOME/kubernetes
  git checkout $TRAVIS_KUBE_VERSION
  kubectl config set-credentials myself --username=admin --password=admin
  kubectl config set-context local --cluster=local --user=myself
  kubectl config set-cluster local --server=http://localhost:8080
  kubectl config use-context local

  # start kubernetes in the background
  sudo PATH=$PATH:/home/travis/.gimme/versions/go1.7.linux.amd64/bin/go \
       KUBE_ENABLE_CLUSTER_DNS=true \
       hack/local-up-cluster.sh &
popd

# Wait untill kube is up and running
TIMEOUT=0
TIMEOUT_COUNT=40
until $( curl --output /dev/null --silent http://localhost:8080 ) || [ $TIMEOUT -eq $TIMEOUT_COUNT ]; do
  echo "Kube is not up yet"
  let TIMEOUT=TIMEOUT+1
  sleep 20
done

if [ $TIMEOUT -eq $TIMEOUT_COUNT ]; then
  echo "Kubernetes is not up and running"
  exit 1
fi

echo "Kubernetes is deployed and reachable"

sudo chown -R $USER:$USER $HOME/.kube

# Have seen issues where chown does not instantly change file permissions.
# When this happens the build.sh cript can have failures.
sleep 1

set -ex

SCRIPTDIR=$(cd $(dirname "$0") && pwd)
ROOTDIR="$SCRIPTDIR/../"

cd $ROOTDIR

# TODO: need official repo
# build openwhisk images
# This way everything that is teset will use the lates openwhisk builds

sed -ie "s/whisk_config:v1.5.6/whisk_config:$TRAVIS_KUBE_VERSION/g" configure/configure_whisk.yml

# run scripts to deploy using the new images.
kubectl apply -f configure/openwhisk_kube_namespace.yml
kubectl apply -f configure/configure_whisk.yml

sleep 5

CONFIGURE_POD=$(kubectl get pods --all-namespaces -o wide | grep configure | awk '{print $2}')

PASSED=false
TIMEOUT=0
until $PASSED || [ $TIMEOUT -eq 25 ]; do
  KUBE_DEPLOY_STATUS=$(kubectl -n openwhisk get jobs | grep configure-openwhisk | awk '{print $3}')
  if [ $KUBE_DEPLOY_STATUS -eq 1 ]; then
    PASSED=true
    break
  fi

  kubectl get pods --all-namespaces -o wide --show-all

  let TIMEOUT=TIMEOUT+1
  sleep 30
done

if [ "$PASSED" = false ]; then
  kubectl -n openwhisk logs $CONFIGURE_POD
  kubectl get jobs --all-namespaces -o wide --show-all
  kubectl get pods --all-namespaces -o wide --show-all

  echo "The job to configure OpenWhisk did not finish with an exit code of 1"
  exit 1
fi

echo "The job to configure OpenWhisk finished successfully"

# Don't try and perform wsk actions the second it finishes deploying.
# The CI ocassionaly fails if you perform actions to quickly.
sleep 30

AUTH_SECRET=$(kubectl -n openwhisk get secret openwhisk-auth-tokens -o yaml | grep 'auth_whisk_system:' | awk '{print $2}' | base64 --decode)
WSK_PORT=$(kubectl -n openwhisk describe service nginx | grep https-api | grep NodePort| awk '{print $3}' | cut -d'/' -f1)

# download the wsk cli from nginx
wget --no-check-certificate https://127.0.0.1:$WSK_PORT/cli/go/download/linux/amd64/wsk
chmod +x wsk

# setup the wsk cli
./wsk property set --auth $AUTH_SECRET --apihost https://127.0.0.1:$WSK_PORT

# create wsk action
cat > hello.js << EOL
function main() {
  return {payload: 'Hello world'};
}
EOL

./wsk -i action create hello hello.js


sleep 5

# run the new hello world action
RESULT=$(./wsk -i action invoke --blocking hello | grep "\"status\": \"success\"")

if [ -z "$RESULT" ]; then
  echo "FAILED! Could not invoked custom action"
  exit 1
fi

echo "PASSED! Deployed openwhisk and invoked custom action"

# push the images to an official repo


