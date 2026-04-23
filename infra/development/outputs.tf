output "aca_env_id" {
  description = "Resource ID of the ACA Environment"
  value       = azurerm_container_app_environment.this.id
}

output "aca_env_name" {
  description = "Name of the ACA Environment"
  value       = azurerm_container_app_environment.this.name
}

output "law_workspace_id" {
  description = "Log Analytics customer ID"
  value       = azurerm_log_analytics_workspace.this.workspace_id
}