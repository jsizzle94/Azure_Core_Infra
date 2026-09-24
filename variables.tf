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