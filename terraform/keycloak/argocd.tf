# create argocd openid client
resource "keycloak_openid_client" "argocd" {
  realm_id              = local.realm_id
  client_id             = "argocd"
  name                  = "argocd"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  client_secret         = "argocd-client-secret"
  standard_flow_enabled = true
  valid_redirect_uris   = ["https://argocd.kind.cluster/auth/callback"]
}

# configure argocd openid client default scopes
resource "keycloak_openid_client_default_scopes" "argocd" {
  realm_id  = local.realm_id
  client_id = keycloak_openid_client.argocd.id
  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    keycloak_openid_client_scope.groups.name,
  ]
}
