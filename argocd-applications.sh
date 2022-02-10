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
  alertmanagerSpec:
    alertmanagerConfigSelector:
      matchLabels: {}
    alertmanagerConfigNamespaceSelector:
      matchLabels: {}
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: ca-issuer
    hosts:
      - alertmanager.kind.cluster
    tls:
      - secretName: argalertmanagerocd.kind.cluster
        hosts:
          - alertmanager.kind.cluster
prometheus:
  prometheusSpec:
    ruleSelectorNilUsesHelmValues: false
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    probeSelectorNilUsesHelmValues: false
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: ca-issuer
    hosts:
      - prometheus.kind.cluster
    tls:
      - secretName: prometheus.kind.cluster
        hosts:
          - prometheus.kind.cluster
grafana:
  enabled: true
  adminPassword: admin
  extraVolumeMounts:
    - name: opt-ca-certificates
      mountPath: /opt/ca-certificates
      readOnly: true
      hostPath: /opt/ca-certificates
      hostPathType: Directory
  securityContext:
    runAsNonRoot: true
  containerSecurityContext:
    allowPrivilegeEscalation: false
    runAsNonRoot: true
  sidecar:
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
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
      root_url: https://grafana.kind.cluster
    auth.generic_oauth:
      enabled: true
      name: Keycloak
      allow_sign_up: true
      scopes: profile,email,groups
      auth_url: https://keycloak.kind.cluster/auth/realms/master/protocol/openid-connect/auth
      token_url: https://keycloak.kind.cluster/auth/realms/master/protocol/openid-connect/token
      api_url: https://keycloak.kind.cluster/auth/realms/master/protocol/openid-connect/userinfo
      client_id: grafana
      client_secret: grafana-client-secret
      tls_client_ca: /opt/ca-certificates/root-ca.pem
      role_attribute_path: contains(groups[*], 'grafana-admin') && 'Admin' || contains(groups[*], 'grafana-dev') && 'Editor' || 'Viewer'
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: ca-issuer
    hosts:
      - grafana.kind.cluster
    tls:
      - secretName: grafana.kind.cluster
        hosts:
          - grafana.kind.cluster
prometheus-node-exporter:
  securityContext:
    runAsNonRoot: true
  containerSecurityContext:
    allowPrivilegeEscalation: false
    runAsNonRoot: true
kube-state-metrics:
  securityContext:
    runAsNonRoot: true
  containerSecurityContext:
    allowPrivilegeEscalation: false
    runAsNonRoot: true
EOF

deploy cilium
deploy cert-manager
# deploy metallb
deploy ingress-nginx
deploy keycloak
deploy argocd
deploy minio
deploy metrics-server
deploy rbac-manager
deploy node-problem-detector
deploy polaris
