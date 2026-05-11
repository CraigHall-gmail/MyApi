output "server_fqdn" {
  description = "Fully-qualified domain name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "database_name" {
  description = "Name of the created database"
  value       = azurerm_postgresql_flexible_server_database.this.name
}

output "connection_string" {
  description = "Full ADO.NET connection string for the database"
  sensitive   = true
  value       = "Host=${azurerm_postgresql_flexible_server.this.fqdn};Port=5432;Database=${var.database_name};Username=${var.admin_username};Password=${var.admin_password};Ssl Mode=Require;Trust Server Certificate=true"
}
