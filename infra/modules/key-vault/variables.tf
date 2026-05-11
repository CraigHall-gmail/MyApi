variable "key_vault_name" {
  type        = string
  description = "Name of the Key Vault (globally unique, 3–24 alphanumeric/hyphen chars)"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to deploy into"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "secret_name" {
  type        = string
  description = "Name of the secret to store in the Key Vault"
  default     = "db-connection-string"
}

variable "secret_value" {
  type        = string
  sensitive   = true
  description = "Value of the secret to store"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
