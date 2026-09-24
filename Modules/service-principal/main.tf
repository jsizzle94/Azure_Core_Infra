data "azuread_client_config" "current" {}

resource "azuread_application" "this" {
  display_name = "example"
  owners       = [data.azuread_client_config.current.object_id]
  
}

resource "azuread_service_principal" "example" {
  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

