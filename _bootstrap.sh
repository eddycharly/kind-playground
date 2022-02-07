#!/bin/bash

set -e

# FUNCTIONS

gitops(){
  kubectl apply -n argocd -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $1
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: $2
    chart: $3
    targetRevision: '*'
    helm:
      values: |
$(sed -e 's/^/        /' .temp/$1.yaml)
  destination:
    server: https://kubernetes.default.svc
    namespace: $4
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

# RUN

./cluster.sh
./keycloak.sh
./argocd.sh

# gitops cilium         https://helm.cilium.io                      cilium          kube-system
# gitops metallb        https://metallb.github.io/metallb           metallb         metallb-system
# gitops ingress-nginx  https://kubernetes.github.io/ingress-nginx  ingress-nginx   ingress-nginx
# gitops keycloak       https://codecentric.github.io/helm-charts   keycloak        keycloak
# gitops argocd         https://argoproj.github.io/argo-helm        argo-cd         argocd

# kubectl apply --recursive -n argocd -f argocd/apps
# kubectl apply --recursive -f manifests

log "CLUSTER READY !"
