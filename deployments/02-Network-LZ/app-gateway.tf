# Application Gateway and Supporting Infrastructure

resource "azurerm_subnet" "appgw" {
  name                                           = "appgwSubnet"
  resource_group_name                            = azurerm_resource_group.rg.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = ["10.1.1.0/24"]
  # enforce_private_link_endpoint_network_policies = false

}

resource "azurerm_public_ip" "appgw" {
  name                = "appgw-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

module "appgw" {
  source = "../../modules/app_gw"

  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  location             = azurerm_resource_group.rg.location
  appgw_name           = "lzappgw"
  frontend_subnet      = azurerm_subnet.appgw.id
  appgw_pip            = azurerm_public_ip.appgw.id

}

output "gateway_name" {
  value = module.appgw.gateway_name
}

output "gateway_id" {
  value = module.appgw.gateway_id
}
