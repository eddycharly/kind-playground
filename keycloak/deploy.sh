#!/bin/bash

set -e

# CONSTANTS

readonly DNSMASQ_DOMAIN=kind.cluster
readonly TF_STATE=../.tf-state/keycloak.tfstate

# FUNCTIONS

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}

keycloak(){
  log "KEYCLOAK ..."

  helm upgrade --install --wait --atomic --namespace keycloak --create-namespace --repo https://codecentric.github.io/helm-charts keycloak keycloak --values - <<EOF
extraEnv: |
  - name: KEYCLOAK_USER
    value: admin
  - name: KEYCLOAK_PASSWORD
    value: admin
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
  rules:
    - host: keycloak.$DNSMASQ_DOMAIN
      paths:
        - path: /
          pathType: Prefix
  tls: null
EOF
}

keycloak_config(){
  log "KEYCLOAK CONFIG ..."

  terraform init && terraform apply -auto-approve -state=$TF_STATE
}

cleanup(){
  log "CLEANUP ..."

  rm -f $TF_STATE
  rm -f .terraform.lock.hcl
  rm -rf .terraform
}

# RUN

cleanup
keycloak
keycloak_config

# DONE

log "KEYCLOAK READY !"

echo "KEYCLOAK: http://keycloak.$DNSMASQ_DOMAIN"
