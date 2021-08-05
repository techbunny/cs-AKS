# Data From Existing Infrastructure

data "terraform_remote_state" "existing-hub" {
  backend = "remote"

  config = {
    organization = "jcroth"

    workspaces = {
      name = "cs-aks-hub"
    }
  }
}

# Resource Group for Landing Zone
# This RG uses the same region location as the Hub. 
resource "azurerm_resource_group" "rg" {
  name     = "${var.lz_prefix}-rg"
  location = data.terraform_remote_state.existing-hub.outputs.rg_location
}

output "lz_rg_location" {
  value = azurerm_resource_group.rg.location
}

output "lz_rg_name" {
  value = azurerm_resource_group.rg.name
}














