variable "resource_group" {
  type        = string
  description = "Name of the Azure resource group"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "southafricanorth"
}

variable "law_name" {
  type        = string
  description = "Name of the Log Analytics Workspace"
}

variable "aca_env_name" {
  type        = string
  description = "Name of the Azure Container App Environment"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
