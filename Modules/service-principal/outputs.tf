output "serviceprincipalinfo" {
  value = {
    SP_Name = var.sptype == "serviceprincipal" ? azuread_service_principal.example[0].display_name : null
    SP_ID = var.sptype == "serviceprincipal" ? azuread_service_principal.example[0].object_id : null
    Managed_SP_Name = var.sptype == "managed" ? azurerm_user_assigned_identity.this[0].name : null
    Managed_SP_ID = var.sptype == "managed" ? azurerm_user_assigned_identity.this[0].principal_id : null
    Managed_SP_ResoureID = var.sptype == "managed" ? azurerm_user_assigned_identity.this[0].id : null

}
}