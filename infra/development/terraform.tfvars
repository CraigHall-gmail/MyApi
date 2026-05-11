resource_group = "rg-myapi-dev"
aca_name_env   = "aca-myapi-dev"
law_name_env   = "law-myapi-dev"
location       = "southafricanorth"

acr_name           = "acrimagereg"
acr_resource_group = "Playground"
app_name           = "myapi"

cpu          = 0.3
memory       = "500mi"
min_replicas = 1
max_replicas = 3

tags = {
  project     = "myapi"
  environment = "dev"
  managed_by  = "terraform"
}

# PostgreSQL — pg_admin_password is supplied via TF_VAR_pg_admin_password (GitHub Secret)
# Key Vault names must be globally unique across Azure; adjust if taken.
pg_server_name    = "psql-myapi-dev"
pg_key_vault_name = "kv-myapi-dev"
pg_sku_name       = "B_Standard_B1ms"
pg_storage_mb     = 32768
