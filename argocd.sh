#!/bin/bash

set -e

# CONSTANTS

readonly DNSMASQ_DOMAIN=kind.cluster

# FUNCTIONS

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}

argocd(){
  log "ARGOCD ..."

  helm upgrade --install --wait --timeout 15m --atomic --namespace argocd --create-namespace \
    --repo https://argoproj.github.io/argo-helm argocd argo-cd --values - <<EOF
dex:
  enabled: false
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
    resource.compareoptions: |
      ignoreResourceStatusField: all
    oidc.config: |
      name: Keycloak
      issuer: http://keycloak.$DNSMASQ_DOMAIN/auth/realms/master
      clientID: argocd
      clientSecret: argocd-client-secret
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
