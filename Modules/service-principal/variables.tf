variable "spname" {
  type = string
}

variable "rgname" {
  type = string
}

variable "location" {
  type = string
}

variable "sptype" {
  type = string
  default = "serviceprincipal"
  
  validation {
    condition = contains(["serviceprincipal", "managed"], var.sptype)
    error_message = "SP Type can only be 'serviceprincipal or managed"
  }
}