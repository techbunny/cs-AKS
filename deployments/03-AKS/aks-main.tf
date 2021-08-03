# Data From Existing Infrastructure

data "terraform_remote_state" "existing-lz" {
  backend = "remote"

  config = {
    organization = "jcroth"

    workspaces = {
      name = "cs-aks-lz"
    }
  }
}

data "azurerm_client_config" "current" {}


# Variables - AKS Cluster

variable "prefix" {
  default = "escs"

}

variable "admin_password" {
  
}


# MSI for Kubernetes Cluster
# This ID is used by the cluster to create or act on other resources in Azure.
# It is referenced in the "identity" block in the azurerm_kubernetes_cluster resource.
#(will need access to Route Table, ACR, KV...)

resource "azurerm_user_assigned_identity" "mi-aks" {
  name                = "mi-${var.prefix}-aks"
  resource_group_name = data.terraform_remote_state.existing-lz.outputs.lz_rg_name
  location            = data.terraform_remote_state.existing-lz.outputs.lz_rg_location
}


# Deploy Azure Container Registry

module "create_acr" {
  source = "../../modules/acr-private"

  acrname             = "acr${var.prefix}"
  resource_group_name = data.terraform_remote_state.existing-lz.outputs.lz_rg_name
  location            = data.terraform_remote_state.existing-lz.outputs.lz_rg_location
  aks_sub_id          = data.terraform_remote_state.existing-lz.outputs.aks_subnet_id
  private_zone_id     = data.terraform_remote_state.existing-lz.outputs.acr_private_zone_id

}

resource "azurerm_role_assignment" "aks-to-acr" {
  scope                = module.create_acr.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.mi-aks.principal_id

}


# Deploy Azure Key Vault

module "create_kv" {
  source                   = "../../modules/kv-private"
  name                     = "kv-${var.prefix}"
  resource_group_name = data.terraform_remote_state.existing-lz.outputs.lz_rg_name
  location            = data.terraform_remote_state.existing-lz.outputs.lz_rg_location
  tenant_id                = data.azurerm_client_config.current.tenant_id
  vnet_id                  = data.terraform_remote_state.existing-lz.outputs.lz_vnet_id
  dest_sub_id              = data.terraform_remote_state.existing-lz.outputs.aks_subnet_id
  private_zone_id          = data.terraform_remote_state.existing-lz.outputs.kv_private_zone_id
  private_zone_name        = data.terraform_remote_state.existing-lz.outputs.kv_private_zone_name
  zone_resource_group_name = data.terraform_remote_state.existing-lz.outputs.lz_rg_name

}


# Deploy AKS Cluster

resource "azurerm_role_assignment" "aks-to-rt" {
  scope                = data.terraform_remote_state.existing-lz.outputs.lz_rt_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.mi-aks.principal_id
}

resource "azurerm_role_assignment" "aks-to-vnet" {
  scope                = data.terraform_remote_state.existing-lz.outputs.lz_vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.mi-aks.principal_id

}

resource "azurerm_log_analytics_workspace" "aks" {
  name                = "aks-la-01"
  resource_group_name = data.terraform_remote_state.existing-lz.outputs.lz_rg_name
  location            = data.terraform_remote_state.existing-lz.outputs.lz_rg_location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

module "aks" {
  source = "../../modules/aks"
  depends_on = [
    azurerm_role_assignment.aks-to-vnet
  ]

  resource_group_name = data.terraform_remote_state.existing-lz.outputs.lz_rg_name
  location            = data.terraform_remote_state.existing-lz.outputs.lz_rg_location
  prefix              = "aks-${var.prefix}"
  vnet_subnet_id = data.terraform_remote_state.existing-lz.outputs.aks_subnet_id
  mi_aks_id           = azurerm_user_assigned_identity.mi-aks.id
  la_id = azurerm_log_analytics_workspace.aks.id
  gateway_name = data.terraform_remote_state.existing-lz.outputs.gateway_name
  gateway_id = data.terraform_remote_state.existing-lz.outputs.gateway_id
  # admin_password = var.admin_password   #for Windows Nodes

}
# This role assigned grants the current user running the deployment admin rights
# to the cluster. In production, this should be an AD Group. 
resource "azurerm_role_assignment" "aks_rbac_admin" {
  scope                = module.aks.aks_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id

}

# Deploy a Linux Server VM

# module "create_linuxsserver" {
#   source = "../TFModules//compute-linux"

#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
#   vnet_subnet_id      = data.terraform_remote_state.existing-lz.outputs.default_subnet_id

#   server_name       = "server-${random_integer.deployment.result}-linux"
#   admin_username                 = var.admin_username
#   admin_ssh                 = var.admin_ssh

# }





