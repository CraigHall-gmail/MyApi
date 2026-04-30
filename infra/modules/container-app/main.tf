data "azurerm_container_registry" "this" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group
}

# Created before the app so AcrPull is assigned before the first image pull.
resource "azurerm_user_assigned_identity" "api" {
  name                = "id-${var.app_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = data.azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

resource "azurerm_container_app" "api" {
  name                         = var.app_name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.aca_env_id
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
      cpu    = var.cpu
      memory = var.memory

      env {
        name  = "PORT"
        value = tostring(var.port)
      }

      liveness_probe {
        transport               = "HTTP"
        path                    = var.liveness_probe_path
        port                    = var.port
        initial_delay           = 10
        interval_seconds        = 30
        failure_count_threshold = 3
      }

      readiness_probe {
        transport               = "HTTP"
        path                    = var.readiness_probe_path
        port                    = var.port
        interval_seconds        = 10
        failure_count_threshold = 3
        success_count_threshold = 1
      }

      startup_probe {
        transport               = "HTTP"
        path                    = var.startup_probe_path
        port                    = var.port
        interval_seconds        = 10
        failure_count_threshold = 30
      }
    }

    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    http_scale_rule {
      name                = "http-scale-rule"
      concurrent_requests = var.http_scale_concurrent_requests
    }
  }

  ingress {
    external_enabled = true
    target_port      = var.port
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.acr_pull]

  lifecycle {
    ignore_changes = [
      template[0].container[0].image, # CD pipeline owns the image
      template[0].container[0].env,   # CD pipeline sets REVISION_LABEL
      ingress[0].traffic_weight,      # CD pipeline manages traffic routing
    ]
  }

  timeouts {
    create = "15m"
    update = "15m"
    delete = "15m"
  }
}
