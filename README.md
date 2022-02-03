# kind-playground

This repository contains code, scripts and manifests i use to play with local
Kubernetes clusters with Kind, Cilium, MetalLB, Keycloak, ArgoCD and various
other tools.

## Basic cluster

The [cluster.sh](./cluster.sh) script will bootstrap a local cluster with Kind and configure it
to use Cilium CNI (without `kube-proxy`), MetalLB, ingress-nginx and dnsmasq.

It will also setup docker image caching through proxies for docker.io, quay.io,
gcr.io and k8s.gcr.io.

Run `./cluster.sh` to create a local cluster.

## Keycloak

The [keycloak](./keycloak) folder contains code to deploy Keycloak in a running cluster.

In addition to deploying Keycloak, it will also configure it using terraform
to be ready to use with ArgoCD and SSO authentication.

Run `cd keycloak && ./deploy.sh && cd -` to deploy and configure Keycloak.

## ArgoCD

The [argocd](./argocd) folder contains code to deploy ArgoCD in a running cluster.

ArgoCD will be configured to use Keycloak OIDC endpoint and SSO authentication.

Run `cd argocd && ./deploy.sh && cd -` to deploy ArgoCD.

## ArgoCD applications

The [argocd/apps](./argocd/apps) folder contains code ArgoCD application manifests.

Run `kubectl -n argocd -f ./argocd/apps/<application name>` to deploy an application.

Available applications:
- [metrics-server](./argocd/apps/metrics-server.yaml)
- [minio](./argocd/apps/minio.yaml)
