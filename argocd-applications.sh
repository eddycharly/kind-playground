#!/bin/bash

set -e

# FUNCTIONS

deploy(){
  kubectl apply -n argocd -f argocd/$1.yaml

  kubectl delete secret -A -l owner=helm,name=$1
}

# RUN

deploy cilium
deploy cert-manager
# deploy metallb
deploy ingress-nginx
deploy kyverno
deploy kyverno-policies
deploy policy-reporter
deploy keycloak
deploy argocd
deploy minio
deploy metrics-server
deploy rbac-manager
deploy node-problem-detector
deploy polaris
deploy kubeview
deploy mattermost-team-edition

kubectl apply -n mattermost -f ./manifests/mattermost-team-edition
