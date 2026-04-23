#!/usr/bin/env bash
# Run once per subscription to create the Terraform remote state backend.
# Prerequisites: az cli logged in with sufficient permissions (Owner or Contributor + RBAC Admin on subscription).

set -euo pipefail

# Prevent Git Bash on Windows from converting /subscriptions/... paths to Windows paths
export MSYS_NO_PATHCONV=1

# ── Config ─────────────────────────────────────────────────────────────────────
RESOURCE_GROUP="rg-myapi-tfstate"
STORAGE_ACCOUNT="myapiterraformstate"
CONTAINER="tfstate"
LOCATION="${LOCATION:-southafricanorth}"

# Object ID of the service principal used by GitHub Actions (OIDC).
# Pass as env var or replace inline: SP_OBJECT_ID="<object-id>"
SP_OBJECT_ID="6eba19ed-4ad3-4380-93ba-e99d0563b1ab" # Github-CraigHall enterprise application

# ── Resource group ─────────────────────────────────────────────────────────────
echo "Creating resource group: $RESOURCE_GROUP"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none

# ── Storage account ────────────────────────────────────────────────────────────
echo "Creating storage account: $STORAGE_ACCOUNT"
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output none

# ── Blob container ─────────────────────────────────────────────────────────────
echo "Creating blob container: $CONTAINER"
az storage container create \
  --name "$CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login \
  --output none

# ── RBAC: GitHub Actions SP ────────────────────────────────────────────────────
STORAGE_ID=$(az storage account show \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query id \
  --output tsv)

echo "Assigning Storage Blob Data Contributor to SP: $SP_OBJECT_ID"
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --scope "$STORAGE_ID" \
  --output none

echo ""
echo "Done. Backend config for main.tf:"
echo "  resource_group_name  = \"$RESOURCE_GROUP\""
echo "  storage_account_name = \"$STORAGE_ACCOUNT\""
echo "  container_name       = \"$CONTAINER\""
