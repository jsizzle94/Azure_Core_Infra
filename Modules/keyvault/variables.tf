variable "location" {
    type = string
    description = "location of resource"
}
variable "rgname" {
    type = string
    description = "name of resource group"
  
}
variable "tenant_id" {
    type = string
    description = "tenant ID of which keyvault will be deployed in"
  
}
variable "kvname" {
    type = string
    description = "Name for keyvault"
  
}