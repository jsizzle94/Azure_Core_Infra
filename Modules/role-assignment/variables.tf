variable "scope" {
  type = string
  description = "Scope of role assigment (what level is it being applied to?resource mgmt group subscription etc?)"
}

variable "role_definition_name" {
  type = string
  description = "Role definition name"
}

variable "principal_id" {
  type = string
  description = "Principal ID of Managed identity"
}