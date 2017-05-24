#!/bin/sh

function install_bluemix_cli() {
  #statements
  echo "Installing Bluemix cli"
  curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx
  sudo mv cf /usr/local/bin
  sudo curl -o /usr/share/bash-completion/completions/cf https://raw.githubusercontent.com/cloudfoundry/cli/master/ci/installers/completion/cf
  cf --version
  curl -L public.dhe.ibm.com/cloud/bluemix/cli/bluemix-cli/Bluemix_CLI_0.5.1_amd64.tar.gz > Bluemix_CLI.tar.gz
  tar -xvf Bluemix_CLI.tar.gz
  sudo ./Bluemix_CLI/install_bluemix_cli
}

function bluemix_auth() {
  echo "Authenticating with Bluemix"
  echo "1" | bx login -a https://api.ng.bluemix.net -u $BLUEMIX_USER -p $BLUEMIX_PASS
  curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
  bx plugin install container-service -r Bluemix
  echo "Installing kubectl"
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
}

function cluster_setup() {
  #change cluster-travis to cluster name
  bx cs workers $CLUSTER
  $(bx cs cluster-config $CLUSTER | grep export)
  echo "Cloning OpenWhisk Repository"
  git clone https://github.com/apache/incubator-openwhisk-deploy-kube.git
  cd incubator-openwhisk-deploy-kube

  echo "Deleting openwhisk namespace if it exists..."
  kubectl delete --ignore-not-found=true -f configure/openwhisk_kube_namespace.yml
  kuber=$(kubectl get ns | grep openwhisk)
  while [ ${#kuber} -ne 0 ]
  do
    sleep 30s
    kubectl get ns
    kuber=$(kubectl get ns | grep openwhisk)
  done
}

function initial_setup() {

  echo "Creating openwhisk namespace..."
  kubectl apply -f configure/openwhisk_kube_namespace.yml
  echo "Creating ClusterRoleBinding..."
  kubectl apply -f ../permission.yaml
  echo "Creating openwhisk job"
  kubectl apply -f configure/configure_whisk.yml

  kubectl get -n openwhisk jobs
  kuber=$(kubectl get -n openwhisk jobs | grep configure | awk '{print $3}')
  while [ $kuber -eq 0 ]
  do
    echo "Configuring openwhisk.."
    sleep 15s
    kubectl get -n openwhisk jobs
    kuber=$(kubectl get -n openwhisk jobs | grep configure | awk '{print $3}')
  done


}

function getting_ip_port() {
echo "Getting IP and Port"
IP=$(kubectl get nodes | grep Ready | awk '{print $1}')
kubectl get nodes
export AUTH_SECRET=$(kubectl -n openwhisk get secret openwhisk-auth-tokens -o yaml | grep 'auth_whisk_system:' | awk '{print $2}' | base64 --decode)
export WSK_PORT=$(kubectl -n openwhisk describe service nginx | grep https-api | grep NodePort| awk '{print $3}' | cut -d'/' -f1)
if [ -z "$IP" ] || [ -z "$WSK_PORT" ] || [ -z "$AUTH_SECRET" ]
then
    echo "IP or NODEPORT not found"
    exit 1
fi
kubectl get pods -n openwhisk

echo "wsk property set --auth $AUTH_SECRET --apihost https://$IP_ADDR:$WSK_PORT"

echo "Travis build successful."
echo "Cleaning up cluster..."
}



install_bluemix_cli
bluemix_auth
cluster_setup
initial_setup
getting_ip_port
cluster_setup
