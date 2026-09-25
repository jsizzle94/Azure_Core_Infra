variable "location" {
  default = "South Africa North"
  type    = string
}
variable "ipsecpsk" {
 type = string
  
}

variable "Lab_Shutdown" {
    description = "Destory expensive lab resources when true"
    type = bool
}

variable "tenant_id" {
    type = string
    description = "tenant ID of which keyvault will be deployed in"
  
}


variable "role_definition_name" {
    type = string
  
}

variable "sptype" {
    type = string
    default = "serviceprincipal"
  
}