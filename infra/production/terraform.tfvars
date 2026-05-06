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

# PostgreSQL — pg_admin_password is supplied via TF_VAR_pg_admin_password (GitHub Secret)
pg_server_name           = "psql-myapi-prd"
pg_key_vault_name        = "kv-myapi-prd"
pg_sku_name              = "GP_Standard_D2s_v3"
pg_storage_mb            = 65536
pg_backup_retention_days = 14
