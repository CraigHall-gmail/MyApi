terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-myapi-tfstate"
    storage_account_name = "myapiterraformstate"
    container_name       = "tfstate"
    key                  = "development/api.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
  # Credentials injected via ARM_* env vars in GitHub Actions (OIDC)
}

# ── Resource Group ─────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "this" {
  name     = var.resource_group
  location = var.location
  tags     = var.tags
}

# ── Log Analytics Workspace ────────────────────────────────────────────────────
resource "azurerm_log_analytics_workspace" "this" {
  name                = var.law_name_env
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ── ACA Environment ────────────────────────────────────────────────────────────
resource "azurerm_container_app_environment" "this" {
  name                       = var.aca_name_env
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = var.tags
}

# ── Container Registry (existing, may live in a shared RG) ────────────────────
data "azurerm_container_registry" "this" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group
}

# ── Container App ──────────────────────────────────────────────────────────────
resource "azurerm_container_app" "api" {
  name                         = var.app_name
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Multiple"

  identity {
    type = "SystemAssigned"
  }

  registry {
    server   = data.azurerm_container_registry.this.login_server
    identity = "System"
  }

  template {
    container {
      name   = var.app_name
      image  = "${data.azurerm_container_registry.this.login_server}/${var.app_name}:${var.image_tag}"
      cpu    = 0.5
      memory = "1Gi"
    }
    min_replicas = 2
    max_replicas = 10
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = var.tags
}

# ── AcrPull role for the container app managed identity ───────────────────────
resource "azurerm_role_assignment" "acr_pull" {
  scope                = data.azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.api.identity[0].principal_id
}
