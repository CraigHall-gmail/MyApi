variable "server_name" {
  type        = string
  description = "Name of the PostgreSQL Flexible Server (globally unique)"
}

variable "database_name" {
  type        = string
  description = "Name of the database to create"
  default     = "myapi"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to deploy into"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "admin_username" {
  type        = string
  description = "PostgreSQL administrator login name"
  default     = "myapiadmin"
}

variable "admin_password" {
  type        = string
  sensitive   = true
  description = "PostgreSQL administrator password (injected via TF_VAR_pg_admin_password)"
}

variable "sku_name" {
  type        = string
  description = "SKU for the PostgreSQL server (e.g. B_Standard_B1ms, GP_Standard_D2s_v3)"
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  type        = number
  description = "Storage size in MB (minimum 32768)"
  default     = 32768
}

variable "backup_retention_days" {
  type        = number
  description = "Number of days to retain backups"
  default     = 7
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
