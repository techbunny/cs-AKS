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
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "jcroth"
    workspaces {
      name = "cs-aks-aks"
    }
  }
}

provider "azurerm" {
  # subscription_id = var.subscription_id
  # tenant_id       = var.tenant_id
  features {}
}

# provider "azurerm" {
#   alias           = "hub"
#   subscription_id = "0fd3a867-7211-409f-9678-9b812ed9aa47"
#   tenant_id       = var.tenant_id
#   features {}
# }