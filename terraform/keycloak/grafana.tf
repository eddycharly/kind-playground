# create argocd openid client
resource "keycloak_openid_client" "grafana" {
  realm_id              = local.realm_id
  client_id             = "grafana"
  name                  = "grafana"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  client_secret         = "grafana-client-secret"
  standard_flow_enabled = true
  valid_redirect_uris   = ["https://grafana.kind.cluster/login/generic_oauth"]
}

# configure argocd openid client default scopes
resource "keycloak_openid_client_default_scopes" "grafana" {
  realm_id  = local.realm_id
  client_id = keycloak_openid_client.grafana.id
  default_scopes = [
    "profile",
    "email",
    keycloak_openid_client_scope.groups.name,
  ]
}
