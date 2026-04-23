variable "resource_group" {
  type        = string
  description = "myapi-production"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "southafricanorth"
}

variable "aca_name_env" {
  type        = string
  description = "aca-myapi"
}

variable "law_name_env" {
  type        = string
  description = "law-myapi"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
