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

variable "image_tag" {
  type        = string
  description = "Container image tag to deploy"
}
