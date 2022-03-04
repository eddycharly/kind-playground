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

get_subnet(){
  docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' $1
}

subnet_to_ip(){
  echo $1 | sed "s@0.0/16@$2@"
}

cleanup(){
  log "CLEANUP ..."

  rm -rf .gitops
}

init(){
  log "INIT ..."

  mkdir .gitops
  git init .gitops
  git -C .gitops remote add origin http://gitea_admin:admin@gitea.kind.cluster/gitea_admin/gitops.git
  git -C .gitops fetch --all || true
  git -C .gitops pull origin master || true
}

install(){
  log "INSTALL ..."

  cp -r helm/ .gitops/

  cat <<EOF > .gitops/config.yaml
prometheus:
  operator:
    enabled: false

dns:
  private: $DNSMASQ_DOMAIN

metallb:
  start: $METALLB_START
  end: $METALLB_END

applications:
  argocd:
    enabled: true
  certManager:
    enabled: true
  cilium:
    enabled: true
  gitea:
    enabled: true
  ingressNginx:
    enabled: true
  keycloak:
    enabled: true
  kubeview:
    enabled: true
  kyverno:
    enabled: true
  kyvernoPolicies:
    enabled: true
  metallb:
    enabled: true
  metricsServer:                        
    enabled: true
  nodeProblemDetector:
    enabled: true
  policyReporter:
    enabled: true
  rbacManager:
    enabled: true
EOF
}

push(){
  log "PUSH ..."

  git -C .gitops add .
  git -C .gitops commit -m "gitops" --allow-empty
  git -C .gitops push -u origin master
}

bootstrap(){
  log "BOOTSTRAP ..."

  local KIND_SUBNET=$(get_subnet kind)
  local METALLB_START=$(subnet_to_ip $KIND_SUBNET 255.200)
  local METALLB_END=$(subnet_to_ip $KIND_SUBNET 255.250)

  kubectl apply -n argocd -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gitops
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: http://gitea.kind.cluster/gitea_admin/gitops
    path: helm/gitops
    targetRevision: HEAD
    helm:
      values: |
        prometheus:
          operator:
            enabled: false
        dns:
          private: $DNSMASQ_DOMAIN
        metallb:
          start: $METALLB_START
          end: $METALLB_END
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  revisionHistoryLimit: 3
  syncPolicy:
    syncOptions:
      - ApplyOutOfSyncOnly=true
      - CreateNamespace=true
      - FailOnSharedResource=true
      - PruneLast=true
    automated:
      prune: true
      selfHeal: true
EOF
}

unhelm(){
  log "REMOVE HELM SECRETS ..."

  kubectl delete secret -A -l owner=helm
}

# RUN

cleanup
init
install
push
bootstrap
unhelm

# DONE

log "GITOPS READY !"
