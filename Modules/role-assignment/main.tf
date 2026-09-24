resource "azurerm_role_assignment" "this" {
principal_id = var.principal_id
scope = var.scope
role_definition_name = var.role_definition_name
}

output "assignment" {
    value = azurerm_role_assignment.this.role_definition_name
  
}