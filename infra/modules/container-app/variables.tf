variable "app_name" {
  type        = string
  description = "Name of the Container App"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to deploy into"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "aca_env_id" {
  type        = string
  description = "Resource ID of the Container App Environment"
}

variable "acr_name" {
  type        = string
  description = "Name of the existing Azure Container Registry"
}

variable "acr_resource_group" {
  type        = string
  description = "Resource group containing the ACR"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
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

variable "port" {
  type        = number
  description = "Port the container listens on"
  default     = 8080
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

variable "liveness_probe_path" {
  type        = string
  description = "HTTP path for the liveness probe"
  default     = "/health/live"
}

variable "readiness_probe_path" {
  type        = string
  description = "HTTP path for the readiness probe"
  default     = "/health/ready"
}

variable "startup_probe_path" {
  type        = string
  description = "HTTP path for the startup probe"
  default     = "/health/live"
}

variable "http_scale_concurrent_requests" {
  type        = string
  description = "Concurrent HTTP requests threshold that triggers a scale-out"
  default     = "100"
}
