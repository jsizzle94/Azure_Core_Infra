output "serviceprincipalinfo" {
  value = {
    name = azuread_service_principal.example.display_name
    id = azuread_service_principal.example.object_id
}
}