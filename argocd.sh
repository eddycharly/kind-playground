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
  volumeMounts:
    - mountPath: /etc/ssl/certs/root-ca.pem
      name: opt-ca-certificates
      readOnly: true
  volumes:
    - name: opt-ca-certificates
      hostPath:
        path: /opt/ca-certificates/root-ca.pem
        type: File
  config:
    url: https://argocd.$DNSMASQ_DOMAIN
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
      issuer: https://keycloak.$DNSMASQ_DOMAIN/auth/realms/master
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
      cert-manager.io/cluster-issuer: ca-issuer
    enabled: true
    hosts:
      - argocd.$DNSMASQ_DOMAIN
    tls:
      - secretName: argocd.$DNSMASQ_DOMAIN
        hosts:
          - argocd.$DNSMASQ_DOMAIN
EOF
}

# RUN

argocd

# DONE

log "ARGOCD READY !"

echo "ARGOCD: https://argocd.$DNSMASQ_DOMAIN"
