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
  to = module.api_app.azurerm_container_app.api
  id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group}/providers/Microsoft.App/containerApps/${var.app_name}"
}

# ── State migrations: flat layout → modules ────────────────────────────────────
moved {
  from = azurerm_resource_group.this
  to   = module.environment.azurerm_resource_group.this
}

moved {
  from = azurerm_log_analytics_workspace.this
  to   = module.environment.azurerm_log_analytics_workspace.this
}

moved {
  from = azurerm_container_app_environment.this
  to   = module.environment.azurerm_container_app_environment.this
}

moved {
  from = azurerm_user_assigned_identity.api
  to   = module.api_app.azurerm_user_assigned_identity.api
}

moved {
  from = azurerm_role_assignment.acr_pull
  to   = module.api_app.azurerm_role_assignment.acr_pull
}

moved {
  from = azurerm_container_app.api
  to   = module.api_app.azurerm_container_app.api
}

# ── Modules ────────────────────────────────────────────────────────────────────
module "environment" {
  source = "../modules/app-environment"

  resource_group = var.resource_group
  location       = var.location
  law_name       = var.law_name_env
  aca_env_name   = var.aca_name_env
  tags           = var.tags
}

module "api_app" {
  source = "../modules/container-app"

  app_name            = var.app_name
  resource_group_name = module.environment.resource_group_name
  location            = module.environment.location
  aca_env_id          = module.environment.aca_env_id
  acr_name            = var.acr_name
  acr_resource_group  = var.acr_resource_group
  tags                = var.tags

  cpu                    = var.cpu
  memory                 = var.memory
  min_replicas           = var.min_replicas
  max_replicas           = var.max_replicas
  aspnetcore_environment = var.aspnetcore_environment
}

module "postgres" {
  source = "../modules/postgres"

  server_name         = var.pg_server_name
  resource_group_name = module.environment.resource_group_name
  location            = module.environment.location
  admin_password      = var.pg_admin_password
  sku_name            = var.pg_sku_name
  storage_mb          = var.pg_storage_mb
  tags                = var.tags
}

module "key_vault" {
  source = "../modules/key-vault"

  key_vault_name      = var.pg_key_vault_name
  resource_group_name = module.environment.resource_group_name
  location            = module.environment.location
  secret_value        = module.postgres.connection_string
  tags                = var.tags
}

# Grant the ACA managed identity read access to the Key Vault so it can be
# used by the CD pipeline and migration workflow to fetch the connection string.
resource "azurerm_role_assignment" "kv_aca_secrets_user" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.api_app.identity_principal_id
}
