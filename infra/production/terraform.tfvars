resource_group = "rg-myapi-production"
aca_name_env   = "aca-myapi-production"
law_name_env   = "law-myapi-production"
location       = "southafricanorth"

acr_name           = "acrimagereg"
acr_resource_group = "Playground"
app_name           = "myapi"

cpu          = 1.0
memory       = "2Gi"
min_replicas = 2
max_replicas = 10

tags = {
  project     = "myapi"
  environment = "production"
  managed_by  = "terraform"
}
