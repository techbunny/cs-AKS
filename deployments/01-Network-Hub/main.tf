# Resource Group for Hub Deployment

resource "azurerm_resource_group" "rg" {
  name     = "${var.hub_prefix}-rg"
  location = var.location
}

# Virtual Network

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.hub_prefix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  address_space       = ["10.0.0.0/16"]
  dns_servers         = null
  tags                = var.tags

}

# Firewall Subnet
# (Additional subnet for Azure Firewall, without NSG as per Firewall requirements)
resource "azurerm_subnet" "firewall" {
  name                                           = "AzureFirewallSubnet"
  resource_group_name                            = azurerm_resource_group.rg.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = ["10.0.1.0/26"]
  enforce_private_link_endpoint_network_policies = false

}

# Gateway Subnet 
# (Additional subnet for Gateway, without NSG as per requirements)
resource "azurerm_subnet" "gateway" {
  name                                           = "GatewaySubnet"
  resource_group_name                            = azurerm_resource_group.rg.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = ["10.0.2.0/27"]
  enforce_private_link_endpoint_network_policies = false

}

# # Bastion - Module creates additional subnet (without NSG), public IP and Bastion
# module "bastion" {
#   source = "../../modules/bastion"

#   subnet_cidr          = "10.0.3.0/26"
#   virtual_network_name = azurerm_virtual_network.vnet.name
#   resource_group_name  = azurerm_resource_group.rg.name
#   location             = azurerm_resource_group.rg.location

# }

# Azure Firewall - Module will create Firewall, Public IP Address
# Firewall Rules created via Module

resource "azurerm_firewall" "firewall" {
  name                = "${azurerm_virtual_network.vnet.name}-firewall"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  firewall_policy_id  = module.firewall_rules_aks.fw_policy_id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

resource "azurerm_public_ip" "firewall" {
  name                 = "${azurerm_virtual_network.vnet.name}-firewall-pip"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  allocation_method    = "Static"
  sku                  = "Standard"
}

module "firewall_rules_aks" {
  source = "../../modules/firewall/AKS-rules"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

}


## OUTPUTS ##
# These outputs are used by later deployments

output "rg_location" {
  value = var.location
}

output "rg_name" {
  value = azurerm_resource_group.rg.name
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "hub_vnet_id" {
  value = azurerm_virtual_network.vnet.id
}


