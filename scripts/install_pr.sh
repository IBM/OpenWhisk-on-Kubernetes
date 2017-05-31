#!/bin/sh

function install_bluemix_kubernetes_cli() {
  #statements
  echo "Installing Bluemix cli"
  curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx
  sudo mv cf /usr/local/bin
  sudo curl -o /usr/share/bash-completion/completions/cf https://raw.githubusercontent.com/cloudfoundry/cli/master/ci/installers/completion/cf
  cf --version
  curl -L public.dhe.ibm.com/cloud/bluemix/cli/bluemix-cli/Bluemix_CLI_0.5.4_amd64.tar.gz > Bluemix_CLI.tar.gz
  tar -xvf Bluemix_CLI.tar.gz
  sudo ./Bluemix_CLI/install_bluemix_cli

  curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
  bx plugin install container-service -r Bluemix
  echo "Installing kubectl"
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
}

function minikube() {
  #Will be added when Docker 1.24 and above is available on Minikube
}

install_bluemix_kubernetes_cli
