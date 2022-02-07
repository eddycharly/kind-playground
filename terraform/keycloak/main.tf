terraform {
  required_providers {
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "3.6.0"
    }
  }
}

# configure keycloak provider
provider "keycloak" {
  client_id                = "admin-cli"
  username                 = "admin"
  password                 = "admin"
  url                      = "https://keycloak.kind.cluster"
  tls_insecure_skip_verify = true
}

locals {
  realm_id = "master"
  groups   = ["argocd-dev", "argocd-admin", "grafana-dev", "grafana-admin", "kube-dev", "kube-admin"]
  user_groups = {
    user-dev   = ["argocd-dev", "grafana-dev", "kube-dev"]
    user-admin = ["argocd-admin", "grafana-admin", "kube-admin"]
  }
}

# create groups
resource "keycloak_group" "groups" {
  for_each = toset(local.groups)
  realm_id = local.realm_id
  name     = each.key
}

# create users
resource "keycloak_user" "users" {
  for_each       = local.user_groups
  realm_id       = local.realm_id
  username       = each.key
  enabled        = true
  email          = "${each.key}@domain.com"
  email_verified = true
  first_name     = each.key
  last_name      = each.key

  initial_password {
    value = each.key
  }
}

# configure use groups membership
resource "keycloak_user_groups" "user_groups" {
  for_each  = local.user_groups
  realm_id  = local.realm_id
  user_id   = keycloak_user.users[each.key].id
  group_ids = [for g in each.value : keycloak_group.groups[g].id]
}

# create groups openid client scope
resource "keycloak_openid_client_scope" "groups" {
  realm_id               = local.realm_id
  name                   = "groups"
  include_in_token_scope = true
  gui_order              = 1
}

resource "keycloak_openid_group_membership_protocol_mapper" "groups" {
  realm_id        = local.realm_id
  client_scope_id = keycloak_openid_client_scope.groups.id
  name            = "groups"
  claim_name      = "groups"
  full_path       = false
}
