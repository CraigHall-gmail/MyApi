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

data "azurerm_client_config" "current" {}

import {
  to = azurerm_container_app.api
  id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group}/providers/Microsoft.App/containerApps/${var.app_name}"
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

# ── User-assigned identity — created before the app so AcrPull can be
#    assigned before the container app tries to pull its first image.
resource "azurerm_user_assigned_identity" "api" {
  name                = "id-${var.app_name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

# ── AcrPull role — must exist before the container app is created ─────────────
resource "azurerm_role_assignment" "acr_pull" {
  scope                = data.azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# ── Container App ──────────────────────────────────────────────────────────────
resource "azurerm_container_app" "api" {
  name                         = var.app_name
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Multiple"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.api.id]
  }

  registry {
    server   = data.azurerm_container_registry.this.login_server
    identity = azurerm_user_assigned_identity.api.id
  }

  template {
    container {
      # Placeholder for initial provisioning — CD workflow deploys the real image.
      name   = var.app_name
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
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

  depends_on = [azurerm_role_assignment.acr_pull]
}
