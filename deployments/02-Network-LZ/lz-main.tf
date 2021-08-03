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

# Virtual Network

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.lz_prefix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.1.0.0/16"] 
  dns_servers         = null
  tags                = var.tags

}

output "lz_vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "lz_vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

# Create Route Table for Landing Zone
# (All subnets in the landing zone will need to connect to this Route Table)
resource "azurerm_route_table" "route_table" {
  name                          = "rt-${var.lz_prefix}"
  resource_group_name = azurerm_resource_group.rg.name 
  location            = azurerm_resource_group.rg.location
  disable_bgp_route_propagation = false

  route {
    name           = "route_to_firewall"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.1.4"
  }

}

output "lz_rt_id" {
  value = azurerm_route_table.route_table.id
}

# Peering Landing Zone (Spoke) Network to Connectivity (Hub) Network
## This assumes that the SP being used for this deployment has Network Contributor rights
## on the subscription(s) where the VNETs reside.  
## If multiple subscriptions are used, provider aliases will be required. 

# Spoke to Hub
resource "azurerm_virtual_network_peering" "direction1" {
  name                         = "${azurerm_virtual_network.vnet.name}-to-${data.terraform_remote_state.existing-hub.outputs.hub_vnet_name}"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.vnet.name
  remote_virtual_network_id    = data.terraform_remote_state.existing-hub.outputs.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
  
}

# Hub to Spoke
resource "azurerm_virtual_network_peering" "direction2" {
  name                         = "${data.terraform_remote_state.existing-hub.outputs.hub_vnet_name}-to-${azurerm_virtual_network.vnet.name}"
  resource_group_name          = data.terraform_remote_state.existing-hub.outputs.rg_name
  virtual_network_name         = data.terraform_remote_state.existing-hub.outputs.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
  
}

# Application Gateway and Supporting Infrastructure

resource "azurerm_subnet" "appgw" {
  name                                           = "appgwSubnet"
  resource_group_name                            = azurerm_resource_group.rg.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = ["10.1.0.0/26"]
  enforce_private_link_endpoint_network_policies = false

}

resource "azurerm_public_ip" "appgw" {
  name                = "appgw-pip"
  resource_group_name                            = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku = "Standard"
}

module "appgw" {
  source = "../../modules/app_gw"

  resource_group_name                            = azurerm_resource_group.rg.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  location            = azurerm_resource_group.rg.location
  appgw_name = "lz-appgw"
  frontend_subnet = azurerm_subnet.appgw.id
  appgw_pip = azurerm_public_ip.appgw.id

}

output "gateway_name" {
  value = module.appgw.gateway_name
}

output "gateway_id" {
  value = module.appgw.gateway_id
}

# This section create a subnet for AKS along with an associated NSG.
# "Here be dragons!" <-- Must elaborate

resource "azurerm_subnet" "aks" {
  name                                           = "aksSubnet"
  resource_group_name                            = azurerm_resource_group.rg.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = ["10.1.16.0/20"]
  enforce_private_link_endpoint_network_policies = true

}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

resource "azurerm_network_security_group" "aks-nsg" {
  name                = "${azurerm_virtual_network.vnet.name}-${azurerm_subnet.aks.name}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_subnet_network_security_group_association" "subnet" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks-nsg.id
}

# Associate Route Table to AKS Subnet
resource "azurerm_subnet_route_table_association" "rt_association" {
  subnet_id      = azurerm_subnet.aks.id
  route_table_id = azurerm_route_table.route_table.id
}

# Deploy DNS Private Zone for ACR

resource "azurerm_private_dns_zone" "acr-dns" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.rg.name
  
}

resource "azurerm_private_dns_zone_virtual_network_link" "lz_acr" {
  name                  = "lz_to_acrs"
  resource_group_name = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.acr-dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

output "acr_private_zone_id" {
  value = azurerm_private_dns_zone.acr-dns.id
}

output "acr_private_zone_name" { 
  value = azurerm_private_dns_zone.acr-dns.name
}

# Deploy DNS Private Zone for KV

resource "azurerm_private_dns_zone" "kv-dns" {
  name                = "vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
  
}

resource "azurerm_private_dns_zone_virtual_network_link" "lz_kv" {
  name                  = "lz_to_kvs"
  resource_group_name = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.kv-dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

output "kv_private_zone_id" {
  value = azurerm_private_dns_zone.kv-dns.id
}

output "kv_private_zone_name" { 
  value = azurerm_private_dns_zone.kv-dns.name
}

# # Deploy DNS Private Zone for AKS

# resource "azurerm_private_dns_zone" "aks-dns" {
#   name                = "privatelink.eastus.azmk8s.io"
#   resource_group_name = azurerm_resource_group.rg.name
  
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "hub_aks" {
#   name                  = "hub_to_aks"
#   resource_group_name = azurerm_resource_group.rg.name
#   private_dns_zone_name = azurerm_private_dns_zone.aks-dns.name
#   virtual_network_id    = module.create_vnet.vnet_id
# }

# output "aks_private_zone_id" {
#   value = azurerm_private_dns_zone.aks-dns.id
# }

# output "aks_private_zone_name" { 
#   value = azurerm_private_dns_zone.aks-dns.name
# }












