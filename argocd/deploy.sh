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

argocd(){
  log "ARGOCD ..."

  local CLIENT_SECRET=$(terraform output -raw -state=$TF_STATE client-secret)

  helm upgrade --install --wait --atomic --namespace argocd --create-namespace  --repo https://argoproj.github.io/argo-helm argocd argo-cd --values - <<EOF
redis:
  enabled: true
redis-ha:
  enabled: false
server:
  config:
    url: http://argocd.$DNSMASQ_DOMAIN
    application.instanceLabelKey: argocd.argoproj.io/instance
    admin.enabled: 'false'
    resource.exclusions: |
      - apiGroups:
          - cilium.io
        kinds:
          - CiliumIdentity
        clusters:
          - '*'
    oidc.config: |
      name: Keycloak
      issuer: http://keycloak.$DNSMASQ_DOMAIN/auth/realms/master
      clientID: argocd
      clientSecret: $CLIENT_SECRET
      requestedScopes: ['openid', 'profile', 'email', 'groups']
  rbacConfig:
    policy.default: role:readonly
    policy.csv: |
      g, argocd-admin, role:admin
  extraArgs:
    - --insecure
  ingress:
    annotations:
      kubernetes.io/ingress.class: nginx
    enabled: true
    hosts:
      - argocd.$DNSMASQ_DOMAIN
EOF
}

# RUN

argocd

# DONE

log "ARGOCD READY !"

echo "ARGOCD: http://argocd.$DNSMASQ_DOMAIN"
