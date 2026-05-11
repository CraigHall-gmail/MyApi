resource "azurerm_resource_group" "this" {
  name     = var.resource_group
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.law_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_container_app_environment" "this" {
  name                       = var.aca_env_name
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = var.tags

  lifecycle {
    # Destroying the environment changes the auto-generated base domain (e.g. lemonbeach-c7269874),
    # breaking all app URLs. Terraform must be told explicitly to recreate it.
    prevent_destroy = true
  }
}
