# Creates cluster with default linux node pool

resource "azurerm_kubernetes_cluster" "akscluster" {
  lifecycle {
   ignore_changes = [
     default_node_pool[0].node_count
   ]
  }

  name                = var.prefix
  dns_prefix          = var.prefix
  location            = var.location
  resource_group_name = var.resource_group_name
  kubernetes_version = "1.21.1"

  addon_profile {
    oms_agent {
      enabled           = true
      log_analytics_workspace_id = var.la_id
    }
    ingress_application_gateway {
      enabled = true 
      gateway_id = var.gateway_id
    }

  }

  default_node_pool {
    name            = "defaultpool"
    vm_size         = "Standard_DS2_v2"
    os_disk_size_gb = 30
    type            = "VirtualMachineScaleSets"
    node_count = 3
    vnet_subnet_id = var.vnet_subnet_id
  }

  network_profile {
    network_plugin = "azure"
    # network_policy = "azure"
    # load_balancer_sku = "Standard"
    outbound_type = "userDefinedRouting"
    dns_service_ip = "192.168.100.10"
    service_cidr = "192.168.100.0/24"
    docker_bridge_cidr = "172.17.0.1/16"

    # load_balancer_profile {
    #   managed_outbound_ip_count = 1
    # }

  }

  role_based_access_control {
    enabled = true

    azure_active_directory {
      managed = true
      azure_rbac_enabled = true
    }
  }

  identity {
    type                      = "UserAssigned"
    user_assigned_identity_id = var.mi_aks_id
  }




  # linux_profile {
  #   admin_username = "sysadmin"

  #   ssh_key {
  #     key_data = file(var.public_ssh_key_path)
  #   }

  # }

  # windows_profile {
  #   admin_username = "sysadmin"
  #   admin_password = var.admin_password
    
  #   }
}

output "aks_id" {
  value = azurerm_kubernetes_cluster.akscluster.id
}

# Created additional Windows Node pool

# resource "azurerm_kubernetes_cluster_node_pool" "windows" {
#   name                  = "wincon"
#   kubernetes_cluster_id = azurerm_kubernetes_cluster.akscluster.id
#   vm_size               = "Standard_DS2_v2"
#   node_count            = 1
#   os_type               = "Windows" #capitalization matters
#   vnet_subnet_id        = var.vnet_subnet_id


# }