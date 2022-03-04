#!/bin/bash

set -e

# RUN

./cluster.sh
./keycloak.sh
./argocd.sh
./gitea.sh
./kube-prometheus-stack.sh
./argocd-applications.sh
