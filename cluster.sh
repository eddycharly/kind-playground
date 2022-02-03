#!/bin/bash

set -e

# CONSTANTS

readonly KIND_NODE_IMAGE=kindest/node:v1.23.1
readonly DNSMASQ_DOMAIN=kind.cluster
readonly DNSMASQ_CONF=kind.k8s.conf

# FUNCTIONS

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}

network(){
  log "NETWORK ..."

  docker network create kind || true
}

proxy(){
  echo "$1 -> $2 ..."

  docker run -d --name $1 --restart=always --net=kind -e REGISTRY_PROXY_REMOTEURL=$2 registry:2 || true
}

proxies(){
  log "REGISTRY PROXIES ..."

  proxy proxy-docker-hub https://registry-1.docker.io
  proxy proxy-quay       https://quay.io
  proxy proxy-gcr        https://gcr.io
  proxy proxy-k8s-gcr    https://k8s.gcr.io
}

get_service_lb_ip(){
  kubectl get svc -n $1 $2 -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
}

get_subnet(){
  docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' $1
}

subnet_to_ip(){
  echo $1 | sed "s@0.0/16@$2@"
}

cluster(){
  log "CLUSTER ..."

  kind create cluster --image $KIND_NODE_IMAGE --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  kubeProxyMode: none
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
    endpoint = ["http://proxy-docker-hub:5000"]
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
    endpoint = ["http://proxy-quay:5000"]
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
    endpoint = ["http://proxy-k8s-gcr:5000"]
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
    endpoint = ["http://proxy-gcr:5000"]
nodes:
- role: control-plane
- role: control-plane
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF
}

cilium(){
  log "CILIUM ..."

  helm upgrade --install --wait --atomic --namespace kube-system --repo https://helm.cilium.io cilium cilium --values - <<EOF
kubeProxyReplacement: strict
k8sServiceHost: kind-external-load-balancer
k8sServicePort: 6443
hostServices:
  enabled: true
externalIPs:
  enabled: true
nodePort:
  enabled: true
hostPort:
  enabled: true
image:
  pullPolicy: IfNotPresent
ipam:
  mode: kubernetes
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
    ingress:
      enabled: true
      annotations:
        kubernetes.io/ingress.class: nginx
      hosts:
        - hubble-ui.$DNSMASQ_DOMAIN
EOF
}

metallb(){
  log "METALLB ..."

  local KIND_SUBNET=$(get_subnet kind)
  local METALLB_START=$(subnet_to_ip $KIND_SUBNET 255.200)
  local METALLB_END=$(subnet_to_ip $KIND_SUBNET 255.250)

  helm upgrade --install --wait --atomic --namespace metallb-system --create-namespace --repo https://metallb.github.io/metallb metallb metallb --values - <<EOF
configInline:
  address-pools:
  - name: default
    protocol: layer2
    addresses:
    - $METALLB_START-$METALLB_END
EOF
}

ingress(){
  log "INGRESS-NGINX ..."

  helm upgrade --install --wait --atomic --namespace ingress-nginx --create-namespace --repo https://kubernetes.github.io/ingress-nginx ingress-nginx ingress-nginx --values - <<EOF
defaultBackend:
  enabled: true
EOF
}

dnsmasq(){
  log "DNSMASQ ..."

  local INGRESS_LB_IP=$(get_service_lb_ip ingress-nginx ingress-nginx-controller)

  echo "address=/$DNSMASQ_DOMAIN/$INGRESS_LB_IP" | sudo tee /etc/dnsmasq.d/$DNSMASQ_CONF
}

restart_service(){
  log "RESTART $1 ..."

  sudo systemctl restart $1
}

cleanup(){
  log "CLEANUP ..."

  kind delete cluster || true
  sudo rm -f /etc/dnsmasq.d/$DNSMASQ_CONF
}

# RUN

cleanup
network
proxies
cluster
cilium
metallb
ingress
dnsmasq
restart_service   dnsmasq

# DONE

log "CLUSTER READY !"

echo "HUBBLE UI: http://hubble-ui.$DNSMASQ_DOMAIN"
