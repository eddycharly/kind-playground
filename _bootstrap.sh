#!/usr/bin/env bash

# VARIABLES

KUBE_PROMETHEUS_STACK=false
GITOPS=false

# FUNCTIONS

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}

verifySupported(){
  if ! type "kubectl" > /dev/null 2>&1; then
    echo "kubectl is required"
    exit 1
  fi

  if ! type "curl" > /dev/null 2>&1; then
    echo "curl is required"
    exit 1
  fi

  if ! type "helm" > /dev/null 2>&1; then
    echo "helm is required"
    exit 1
  fi
}

fail_trap() {
  local RESULT=$?
  log "FAILED WITH RESULT $RESULT !!!"
  exit $RESULT
}

# RUN

trap "fail_trap" EXIT

set -e

set -u

while [[ $# -gt 0 ]]; do
  case $1 in
    '--gitops')
      GITOPS=true
      ;;
    '--kube-prometheus-stack')
      KUBE_PROMETHEUS_STACK=true
      ;;
    *)
      echo "ERROR: Unknown option $1"
      help
      exit 1
      ;;
  esac
  shift
done

set +u

verifySupported

./cluster.sh
./keycloak.sh
./argocd.sh
./gitea.sh

if [ "$KUBE_PROMETHEUS_STACK" == "true" ]; then
    ./kube-prometheus-stack.sh
fi

if [ "$GITOPS" == "true" ]; then
    ./gitops.sh
else
    ./argocd-applications.sh
fi
