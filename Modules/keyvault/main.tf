resource "random_id" "this" {
  byte_length = 2
}



resource "azurerm_key_vault" "this" {
  location = var.location
  name = "${var.kvname}-${random_id.this.id}"
  resource_group_name = var.rgname
  sku_name = "standard"
  tenant_id = var.tenant_id
  rbac_authorization_enabled = true
}

