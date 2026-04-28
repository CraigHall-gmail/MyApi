output "container_app_id" {
  description = "Resource ID of the Container App"
  value       = azurerm_container_app.api.id
}

output "container_app_fqdn" {
  description = "Stable ingress FQDN of the Container App (does not change between revisions)"
  value       = azurerm_container_app.api.ingress[0].fqdn
}

output "identity_id" {
  description = "Resource ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.api.id
}

output "identity_principal_id" {
  description = "Principal ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.api.principal_id
}
