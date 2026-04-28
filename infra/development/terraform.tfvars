resource_group = "rg-myapi-dev"
aca_name_env   = "aca-myapi-dev"
law_name_env   = "law-myapi-dev"
location       = "southafricanorth"

acr_name           = "acrimagereg"
acr_resource_group = "Playground"
app_name           = "myapi"

cpu          = 0.5
memory       = "1Gi"
min_replicas = 1
max_replicas = 5

tags = {
  project     = "myapi"
  environment = "dev"
  managed_by  = "terraform"
}
