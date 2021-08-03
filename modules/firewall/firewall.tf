resource "azurerm_firewall" "firewall" {
  name                = "${var.virtual_network_name}-firewall"
  resource_group_name = var.resource_group_name
  location            = var.location
  firewall_policy_id = var.fw_policy_id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

resource "azurerm_public_ip" "firewall" {
  name                = "${var.virtual_network_name}-firewall-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}


variable "resource_group_name" {
    
}
variable "location" {
    
}

variable "subnet_id" {

}

variable "virtual_network_name" {
    
}

variable "fw_policy_id" {

}


