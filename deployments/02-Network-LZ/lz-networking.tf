# Resource Group for Landing Zone Networking
# This RG uses the same region location as the Hub. 
resource "azurerm_resource_group" "net-rg" {
  name     = "${var.lz_prefix}-rg"
  location = data.terraform_remote_state.existing-hub.outputs.hub_rg_location
}

output "lz_rg_location" {
  value = azurerm_resource_group.net-rg.location
}

output "lz_rg_name" {
  value = azurerm_resource_group.net-rg.name
}


# Virtual Network

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.lz_prefix}"
  resource_group_name = azurerm_resource_group.net-rg.name
  location            = azurerm_resource_group.net-rg.location
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

# # Create Route Table for Landing Zone
# (All subnets in the landing zone will need to connect to this Route Table)
resource "azurerm_route_table" "route_table" {
  name                          = "rt-${var.lz_prefix}"
  resource_group_name = azurerm_resource_group.net-rg.name
  location            = azurerm_resource_group.net-rg.location
  disable_bgp_route_propagation = false

  route {
    name                   = "route_to_firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
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
  resource_group_name          = azurerm_resource_group.net-rg.name
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
  resource_group_name          = data.terraform_remote_state.existing-hub.outputs.hub_rg_name
  virtual_network_name         = data.terraform_remote_state.existing-hub.outputs.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

}