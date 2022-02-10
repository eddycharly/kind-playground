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

# RUN

# deploying kube-prometheus-stack with ArgoCD does not work (CRDs are to big)
# deploy kube-prometheus-stack
kube_prometheus_stack(){
  log "KUBE PROMETHEUS STACK ..."

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
      - alertmanager.$DNSMASQ_DOMAIN
    tls:
      - secretName: alertmanager.$DNSMASQ_DOMAIN
        hosts:
          - alertmanager.$DNSMASQ_DOMAIN
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
      - prometheus.$DNSMASQ_DOMAIN
    tls:
      - secretName: prometheus.$DNSMASQ_DOMAIN
        hosts:
          - prometheus.$DNSMASQ_DOMAIN
grafana:
  enabled: true
  adminPassword: admin
  extraVolumeMounts:
    - name: opt-ca-certificates
      mountPath: /opt/ca-certificates
      readOnly: true
      hostPath: /opt/ca-certificates
      hostPathType: Directory
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
      root_url: https://grafana.$DNSMASQ_DOMAIN
    auth.generic_oauth:
      enabled: true
      name: Keycloak
      allow_sign_up: true
      scopes: profile,email,groups
      auth_url: https://keycloak.$DNSMASQ_DOMAIN/auth/realms/master/protocol/openid-connect/auth
      token_url: https://keycloak.$DNSMASQ_DOMAIN/auth/realms/master/protocol/openid-connect/token
      api_url: https://keycloak.$DNSMASQ_DOMAIN/auth/realms/master/protocol/openid-connect/userinfo
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
      - grafana.$DNSMASQ_DOMAIN
    tls:
      - secretName: grafana.$DNSMASQ_DOMAIN
        hosts:
          - grafana.$DNSMASQ_DOMAIN
EOF
}

# RUN

kube_prometheus_stack

# DONE

log "KUBE PROMETHEUS STACK READY !"

echo "ALERT MANAGER: https://alertmanager.$DNSMASQ_DOMAIN"
echo "GRAFANA:       https://grafana.$DNSMASQ_DOMAIN"
echo "PROMETHEUS:    https://prometheus.$DNSMASQ_DOMAIN"
