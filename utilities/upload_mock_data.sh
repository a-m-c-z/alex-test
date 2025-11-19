#!/bin/bash
# AI used to develop this script quickly.
set -e

echo "Upload Mock VM Inventory to Azure Blob Storage"
echo "=================================================="

# Check prerequisites
command -v az >/dev/null 2>&1 || { echo "Azure CLI not found."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found. Install with: brew install jq"; exit 1; }

# Check authentication
echo ""
echo "Checking Azure authentication..."
az account show > /dev/null 2>&1 || {
    echo "Not logged in. Running az login..."
    az login
}

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Authenticated to subscription: $SUBSCRIPTION_ID"

# Prompt for resource group name (or use default)
echo ""
read -p "Enter resource group name [default is rg-edftest]: " RG_NAME
RG_NAME=${RG_NAME:-rg-edftest}

# Check if resource group exists
echo ""
echo "Checking resource group '$RG_NAME'..."
if ! az group exists --name $RG_NAME | grep -q "true"; then
    echo "Resource group '$RG_NAME' not found"
    echo ""
    echo "Available resource groups:"
    az group list --query "[].name" -o table
    exit 1
fi

echo "Resource group found"

# Find preprocess storage account
echo ""
echo "Finding preprocess storage account..."
PREPROCESS_STORAGE=$(az storage account list \
    --resource-group $RG_NAME \
    --query "[?tags.Project=='SQL-Server-Monitoring' && contains(name, 'preprocess')].name | [0]" \
    -o tsv)

# If not found by tag, try by name pattern
if [ -z "$PREPROCESS_STORAGE" ]; then
    PREPROCESS_STORAGE=$(az storage account list \
        --resource-group $RG_NAME \
        --query "[?contains(name, 'preprocess') || contains(name, 'pre')].name | [0]" \
        -o tsv)
fi

# If still not found, list all and let user choose
if [ -z "$PREPROCESS_STORAGE" ]; then
    echo "Could not auto-detect preprocess storage account."
    echo ""
    echo "Available storage accounts in $RG_NAME:"
    STORAGE_ACCOUNTS=$(az storage account list \
        --resource-group $RG_NAME \
        --query "[].name" -o tsv)
    
    if [ -z "$STORAGE_ACCOUNTS" ]; then
        echo "No storage accounts found in resource group"
        exit 1
    fi
    
    echo "$STORAGE_ACCOUNTS"
    echo ""
    read -p "Enter preprocess storage account name: " PREPROCESS_STORAGE
    
    if [ -z "$PREPROCESS_STORAGE" ]; then
        echo "No storage account specified"
        exit 1
    fi
fi

echo "Storage Account: $PREPROCESS_STORAGE"

# Find container (usually blobpreprocess)
echo ""
echo "🔍 Finding preprocess container..."
PREPROCESS_CONTAINER=$(az storage container list \
    --account-name $PREPROCESS_STORAGE \
    --auth-mode login \
    --query "[?contains(name, 'preprocess') || contains(name, 'pre')].name | [0]" \
    -o tsv 2>/dev/null)

if [ -z "$PREPROCESS_CONTAINER" ]; then
    echo "Could not auto-detect container."
    echo ""
    echo "Available containers:"
    az storage container list \
        --account-name $PREPROCESS_STORAGE \
        --auth-mode login \
        --query "[].name" -o tsv
    echo ""
    read -p "Enter container name [blobpreprocess]: " PREPROCESS_CONTAINER
    PREPROCESS_CONTAINER=${PREPROCESS_CONTAINER:-blobpreprocess}
fi

echo "Container: $PREPROCESS_CONTAINER"

# Check if mock data exists
if [ ! -f "tests/data/vm_inventory.csv" ]; then
    echo "Mock data file not found: tests/data/vm_inventory.csv"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Upload the file
echo ""
echo "Uploading vm_inventory.csv..."

# Try with managed identity/RBAC first, fall back to account key
if az storage blob upload \
    --account-name $PREPROCESS_STORAGE \
    --container-name $PREPROCESS_CONTAINER \
    --name vm_inventory.csv \
    --file tests/data/vm_inventory.csv \
    --overwrite \
    --auth-mode login 2>/dev/null; then
    echo "Uploaded using Azure AD authentication"
else
    echo "RBAC authentication failed, trying with account key..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list \
        --account-name $PREPROCESS_STORAGE \
        --resource-group $RG_NAME \
        --query "[0].value" -o tsv)
    
    if [ -z "$STORAGE_KEY" ]; then
        echo "Could not retrieve storage account key"
        echo ""
        echo "To fix RBAC permissions, run:"
        echo "  az role assignment create \\"
        echo "    --assignee $(az account show --query user.name -o tsv) \\"
        echo "    --role 'Storage Blob Data Contributor' \\"
        echo "    --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/$PREPROCESS_STORAGE"
        exit 1
    fi
    
    az storage blob upload \
        --account-name $PREPROCESS_STORAGE \
        --container-name $PREPROCESS_CONTAINER \
        --name vm_inventory.csv \
        --file tests/data/vm_inventory.csv \
        --account-key "$STORAGE_KEY" \
        --overwrite
    
    echo "Uploaded using storage account key"
fi

echo ""
echo "Upload complete!"
echo ""
echo "File details:"

# Try to show blob details (works with either auth mode)
if [ ! -z "$STORAGE_KEY" ]; then
    az storage blob show \
        --account-name $PREPROCESS_STORAGE \
        --container-name $PREPROCESS_CONTAINER \
        --name vm_inventory.csv \
        --account-key "$STORAGE_KEY" \
        --query "{Name:name, Size:properties.contentLength, LastModified:properties.lastModified}" \
        --output table
else
    az storage blob show \
        --account-name $PREPROCESS_STORAGE \
        --container-name $PREPROCESS_CONTAINER \
        --name vm_inventory.csv \
        --auth-mode login \
        --query "{Name:name, Size:properties.contentLength, LastModified:properties.lastModified}" \
        --output table
fi

echo ""
echo "View in Azure Portal:"
echo "https://portal.azure.com/#view/Microsoft_Azure_Storage/ContainerMenuBlade/~/overview/storageAccountId/%2Fsubscriptions%2F$SUBSCRIPTION_ID%2FresourceGroups%2F$RG_NAME%2Fproviders%2FMicrosoft.Storage%2FstorageAccounts%2F$PREPROCESS_STORAGE/path/$PREPROCESS_CONTAINER"

echo ""
echo "Next steps:"
echo "   1. Trigger the function to process this data"
echo "   2. Check the postprocess container for the filtered output"
echo ""
echo "To trigger the function manually:"
echo "  az functionapp function show --name <function-app-name> --resource-group $RG_NAME --function-name filter_sql_servers"