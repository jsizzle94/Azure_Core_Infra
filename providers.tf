terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=5.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.1.0"
    }
    random = {
      source = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azuread" {
  tenant_id = "af035a01-b607-4b1f-a2f7-1b622a6542e3"
}

provider "azurerm" {
  features {}
  
}

