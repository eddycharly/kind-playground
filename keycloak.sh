#!/usr/bin/env bash

set -e

# CONSTANTS

readonly DNSMASQ_DOMAIN=kind.cluster
readonly TF_STATE=.tf-state/keycloak.tfstate

# FUNCTIONS

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}

keycloak(){
  log "KEYCLOAK ..."

  helm upgrade --install --wait --timeout 15m --atomic --namespace keycloak --create-namespace \
    --repo https://charts.bitnami.com/bitnami keycloak keycloak --reuse-values --values - <<EOF
auth:
  createAdminUser: true
  adminUser: admin
  adminPassword: admin
  managementUser: manager
  managementPassword: manager
proxyAddressForwarding: true
ingress:
  enabled: true
  hostname: keycloak.kind.cluster
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: ca-issuer
  tls: true
postgresql:
  enabled: true
  auth:
    postgresPassword: password
    password: password
EOF
}

keycloak_config(){
  log "KEYCLOAK CONFIG ..."

  terraform -chdir=./terraform/keycloak init && terraform -chdir=./terraform/keycloak apply -auto-approve -state=$TF_STATE
}

cleanup(){
  log "CLEANUP ..."

  terraform -chdir=./terraform/keycloak init && terraform -chdir=./terraform/keycloak destroy -auto-approve -state=$TF_STATE || true
  rm -f   ./terraform/keycloak/$TF_STATE
  rm -f   ./terraform/keycloak/.terraform.lock.hcl
  rm -rf  ./terraform/keycloak/.terraform
}

rbac(){
  log "RBAC ..."

  kubectl apply -f - <<EOF
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kube-admin
subjects:
  - kind: Group
    name: kube-admin
    apiGroup: rbac.authorization.k8s.io
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
EOF

  kubectl apply -f - <<EOF
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kube-dev
subjects:
  - kind: Group
    name: kube-dev
    apiGroup: rbac.authorization.k8s.io
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
EOF
}

kubectl_config(){
  log "KUBECTL ..."

  local ID_TOKEN=$(curl -X POST https://keycloak.kind.cluster/auth/realms/master/protocol/openid-connect/token \
    -d grant_type=password \
    -d client_id=kube \
    -d client_secret=kube-client-secret \
    -d username=$1 \
    -d password=$1 \
    -d scope=openid \
    -d response_type=id_token | jq -r '.id_token')

  local REFRESH_TOKEN=$(curl -X POST https://keycloak.kind.cluster/auth/realms/master/protocol/openid-connect/token \
    -d grant_type=password \
    -d client_id=kube \
    -d client_secret=kube-client-secret \
    -d username=$1 \
    -d password=$1 \
    -d scope=openid \
    -d response_type=id_token | jq -r '.refresh_token')

  local CA_DATA=$(cat .ssl/root-ca.pem | base64 | tr -d '\n')

  kubectl config set-credentials $1 \
    --auth-provider=oidc \
    --auth-provider-arg=client-id=kube \
    --auth-provider-arg=client-secret=kube-client-secret \
    --auth-provider-arg=idp-issuer-url=https://keycloak.kind.cluster/auth/realms/master \
    --auth-provider-arg=id-token=$ID_TOKEN \
    --auth-provider-arg=refresh-token=$REFRESH_TOKEN \
    --auth-provider-arg=idp-certificate-authority-data=$CA_DATA

  kubectl config set-context $1 --cluster=kind-kind --user=$1
}

# RUN

cleanup
keycloak
keycloak_config
rbac
kubectl_config    user-admin
kubectl_config    user-dev

# DONE

log "KEYCLOAK READY !"

echo "KEYCLOAK: https://keycloak.$DNSMASQ_DOMAIN"
