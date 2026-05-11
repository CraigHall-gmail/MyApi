output "aca_env_id" {
  description = "Resource ID of the ACA Environment"
  value       = module.environment.aca_env_id
}

output "aca_env_name" {
  description = "Name of the ACA Environment"
  value       = module.environment.aca_env_name
}

output "law_workspace_id" {
  description = "Log Analytics customer ID"
  value       = module.environment.law_workspace_id
}

output "app_fqdn" {
  description = "Fully-qualified domain name of the Container App"
  value       = module.api_app.container_app_fqdn
}

output "pg_server_fqdn" {
  description = "FQDN of the PostgreSQL Flexible Server"
  value       = module.postgres.server_fqdn
}

output "key_vault_name" {
  description = "Name of the Key Vault holding the DB connection string"
  value       = module.key_vault.key_vault_name
}
