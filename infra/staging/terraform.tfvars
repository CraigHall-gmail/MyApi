resource_group = "rg-myapi-staging"
aca_name_env   = "aca-myapi-staging"
law_name_env   = "law-myapi-staging"
location       = "southafricanorth"

acr_name           = "acrimagereg"
acr_resource_group = "Playground"
app_name           = "myapi-stg"

cpu          = 0.5
memory       = "1Gi"
min_replicas = 1
max_replicas = 5

tags = {
  project     = "myapi"
  environment = "staging"
  managed_by  = "terraform"
}

# PostgreSQL — pg_admin_password is supplied via TF_VAR_pg_admin_password (GitHub Secret)
pg_server_name    = "psql-myapi-stg"
pg_key_vault_name = "kv-myapi-stg"
pg_sku_name       = "B_Standard_B2ms"
pg_storage_mb     = 32768
