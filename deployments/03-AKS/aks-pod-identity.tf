# These resources will set up the required permissions for 
# AAD Pod Identity (v1)


# Managed Identity for Pod Identity
resource "azurerm_user_assigned_identity" "aks_pod_identity" {
  resource_group_name = azurerm_resource_group.rg-aks.name
  location            = azurerm_resource_group.rg-aks.location
  name                = "pod-identity-example"
}


# Role assignments
resource "azurerm_role_assignment" "aks_identity_operator" {
  scope                = azurerm_user_assigned_identity.aks_pod_identity.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = module.aks.kubelet_id
}

resource "azurerm_role_assignment" "aks_vm_contributor" {
  scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourcegroups/${module.aks.node_pool_rg}"
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = module.aks.kubelet_id
}

# Outputs
output "aad_pod_identity_resource_id" {
  value       = azurerm_user_assigned_identity.aks_pod_identity.id
  description = "Resource ID for the Managed Identity for AAD Pod Identity"
}

output "aad_pod_identity_client_id" {
  value       = azurerm_user_assigned_identity.aks_pod_identity.client_id
  description = "Client ID for the Managed Identity for AAD Pod Identity"
}