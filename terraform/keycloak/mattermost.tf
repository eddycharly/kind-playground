# create mattermost openid client
resource "keycloak_openid_client" "mattermost" {
  realm_id              = local.realm_id
  client_id             = "mattermost"
  name                  = "mattermost"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  client_secret         = "mattermost-client-secret"
  standard_flow_enabled = true
  valid_redirect_uris   = ["https://mattermost.kind.cluster/signup/gitlab/complete"]
}

resource "keycloak_openid_user_property_protocol_mapper" "username" {
  realm_id            = local.realm_id
  client_id           = keycloak_openid_client.mattermost.id
  name                = "username"
  user_property       = "username"
  claim_name          = "username"
  claim_value_type    = "String"
  add_to_id_token     = false
  add_to_access_token = false
  add_to_userinfo     = true
}

resource "keycloak_openid_user_attribute_protocol_mapper" "gitlab_id" {
  realm_id            = local.realm_id
  client_id           = keycloak_openid_client.mattermost.id
  name                = "gitlab_id"
  user_attribute      = "gitlab_id"
  claim_name          = "id"
  claim_value_type    = "long"
  add_to_id_token     = false
  add_to_access_token = false
  add_to_userinfo     = true
}

# configure mattermost openid client default scopes
resource "keycloak_openid_client_default_scopes" "mattermost" {
  realm_id  = local.realm_id
  client_id = keycloak_openid_client.mattermost.id
  default_scopes = [
    "email",
  ]
}
