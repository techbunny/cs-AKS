terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.61"
    }
    random = {
      version = ">=3.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "tfstate"
    storage_account_name = "escstfstate"
    container_name       = "escs"
    key                  = "aks"
  }
}

provider "azurerm" {
  features {}
}

# provider "azurerm" {
#   alias           = "hub"
#   subscription_id = "0fd3a867-7211-409f-9678-9b812ed9aa47"
#   tenant_id       = var.tenant_id
#   features {}
# }