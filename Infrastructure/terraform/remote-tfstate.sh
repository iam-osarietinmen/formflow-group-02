#!/usr/bin/env bash

# Set these variables first
LOCATION="uksouth"
RG_NAME="tfstate-rg"
STORAGE_NAME="tfstateformflow$(date +%s | tail -c 5)"   # makes it unique

# Create everything
az group create --name $RG_NAME --location $LOCATION

az storage account create \
  --name $STORAGE_NAME \
  --resource-group $RG_NAME \
  --location $LOCATION \
  --sku Standard_LRS \
  --encryption-services blob \
  --allow-blob-public-access false

az storage container create \
  --name tfstate \
  --account-name $STORAGE_NAME \
  --auth-mode login

echo "======================================"
echo "Use these values in GitHub Variables:"
echo "TF_STATE_RESOURCE_GROUP = $RG_NAME"
echo "TF_STATE_STORAGE_ACCOUNT = $STORAGE_NAME"
echo "TF_STATE_CONTAINER = tfstate"
echo "TF_STATE_KEY = formflow-prod.tfstate"
echo "======================================"