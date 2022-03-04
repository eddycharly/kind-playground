#!/usr/bin/env bash

set -e

# CONSTANTS

readonly DNSMASQ_DOMAIN=kind.cluster

# FUNCTIONS

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}

gitea(){
  log "GITEA ..."

  helm upgrade --install --wait --timeout 15m --atomic --namespace gitea --create-namespace \
    --repo https://dl.gitea.io/charts gitea gitea --values - <<EOF
gitea:
  admin:
    username: gitea_admin
    password: admin
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: ca-issuer
    nginx.ingress.kubernetes.io/ssl-redirect: 'false'
  hosts:
    - host: gitea.$DNSMASQ_DOMAIN
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: gitea.$DNSMASQ_DOMAIN
      hosts:
        - gitea.$DNSMASQ_DOMAIN
EOF
}

repository(){
  local NAME=${1:-gitops}
  curl -X POST \
    -u gitea_admin:admin \
    https://gitea.kind.cluster/api/v1/user/repos \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -d @- <<EOF
{
  "name": "$NAME"
}
EOF
}

# RUN

gitea
repository  gitops

# DONE

log "GITEA READY !"

echo "GITEA: https://gitea.$DNSMASQ_DOMAIN"
