data "azuread_client_config" "current" {}

resource "azuread_application" "this" {
  count = var.sptype == "serviceprincipal" ? 1 : 0
  display_name = "${var.spname}"
  owners       = [data.azuread_client_config.current.object_id]
  
}

resource "azuread_service_principal" "example" {
  count = var.sptype == "serviceprincipal" ? 1 : 0 
  client_id                    = azuread_application.this[0].client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azurerm_user_assigned_identity" "this" {
  count = var.sptype == "managed" ? 1 : 0 
  location = var.location
  name = var.spname
  resource_group_name = var.rgname

}