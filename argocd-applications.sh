#!/bin/bash

set -e

# FUNCTIONS

deploy(){
  kubectl apply -n argocd -f argocd/$1.yaml

  kubectl delete secret -A -l owner=helm,name=$1
}

# RUN

# deploying kube-prometheus-stack with ArgoCD does not work (CRDs are to big)
# deploy kube-prometheus-stack
helm upgrade --install --wait --timeout 15m --namespace monitoring --create-namespace \
  --repo https://prometheus-community.github.io/helm-charts kube-prometheus-stack kube-prometheus-stack \
  --values - <<EOF
kubeEtcd:
  service:
    enabled: true
    targetPort: 2381
kubeProxy:
  enabled: false
defaultRules:
  create: true
  rules:
    kubeProxy: false
alertmanager:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
    hosts:
    - alertmanager.kind.cluster
prometheus:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
    hosts:
    - prometheus.kind.cluster
grafana:
  enabled: true
  adminPassword: admin
  sidecar:
    enableUniqueFilenames: true
    dashboards:
      enabled: true
      searchNamespace: ALL
      provider:
        foldersFromFilesStructure: true
    datasources:
      enabled: true
      searchNamespace: ALL
  grafana.ini:
    server:
      root_url: http://grafana.kind.cluster
    auth.generic_oauth:
      enabled: true
      name: Keycloak
      allow_sign_up: true
      scopes: profile,email,groups
      auth_url: http://keycloak.kind.cluster/auth/realms/master/protocol/openid-connect/auth
      token_url: http://keycloak.kind.cluster/auth/realms/master/protocol/openid-connect/token
      api_url: http://keycloak.kind.cluster/auth/realms/master/protocol/openid-connect/userinfo
      client_id: grafana
      client_secret: grafana-client-secret
      role_attribute_path: contains(groups[*], 'grafana-admin') && 'Admin' || contains(groups[*], 'grafana-dev') && 'Editor' || 'Viewer'
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
    hosts:
    - grafana.kind.cluster
EOF

deploy cilium
# deploy metallb
deploy ingress-nginx
deploy keycloak
deploy argocd
deploy minio
deploy metrics-server
