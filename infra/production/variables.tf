variable "resource_group" {
  type        = string
  description = "Name of the Azure resource group"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "southafricanorth"
}

variable "aca_name_env" {
  type        = string
  description = "Name of the Azure Container App Environment"
}

variable "law_name_env" {
  type        = string
  description = "Name of the Log Analytics Workspace"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}

variable "acr_name" {
  type        = string
  description = "Name of the existing Azure Container Registry"
}

variable "acr_resource_group" {
  type        = string
  description = "Resource group containing the ACR"
}

variable "app_name" {
  type        = string
  description = "Name of the Container App"
}

variable "cpu" {
  type        = number
  description = "CPU allocation for the container"
  default     = 0.5
}

variable "memory" {
  type        = string
  description = "Memory allocation for the container (e.g. '1Gi')"
  default     = "1Gi"
}

variable "min_replicas" {
  type        = number
  description = "Minimum number of replicas"
  default     = 1
}

variable "max_replicas" {
  type        = number
  description = "Maximum number of replicas"
  default     = 10
}

variable "aspnetcore_environment" {
  type        = string
  description = "ASPNETCORE_ENVIRONMENT injected into the container"
  default     = "Production"
}

variable "pg_zone" {
  type        = string
  description = "Availability zone for the PostgreSQL server"
  default     = "1"
}

variable "pg_server_name" {
  type        = string
  description = "Name of the PostgreSQL Flexible Server (globally unique)"
}

variable "pg_key_vault_name" {
  type        = string
  description = "Name of the Key Vault (globally unique, 3–24 chars)"
}

variable "pg_admin_password" {
  type        = string
  sensitive   = true
  description = "PostgreSQL admin password — injected via TF_VAR_pg_admin_password in CI"
}

variable "pg_sku_name" {
  type        = string
  description = "PostgreSQL SKU (e.g. GP_Standard_D2s_v3)"
  default     = "GP_Standard_D2s_v3"
}

variable "pg_storage_mb" {
  type        = number
  description = "PostgreSQL storage in MB"
  default     = 65536
}

variable "pg_backup_retention_days" {
  type        = number
  description = "PostgreSQL backup retention in days"
  default     = 14
}
