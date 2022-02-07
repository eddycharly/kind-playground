#!/bin/bash

set -e

# FUNCTIONS

deploy(){
  kubectl apply -n argocd -f argocd/$1.yaml

  kubectl delete secret -A -l owner=helm,name=$1
}

# RUN

deploy kube-prometheus-stack
deploy cilium
# deploy metallb
deploy ingress-nginx
deploy keycloak
deploy argocd
deploy minio
deploy metrics-server
