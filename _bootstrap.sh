#!/bin/bash

set -e

# RUN

./cluster.sh
./keycloak.sh
./argocd.sh
./argocd-applications.sh
