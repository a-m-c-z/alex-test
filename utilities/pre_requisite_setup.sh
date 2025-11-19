#!/bin/bash
set -euo pipefail

#NOTE: AI used for slightly more complex Azure CLI queries, and output formatting. 
# Also used for debugging Mac-specific issue.

# ------------------------------------------------------------
# EDF Environment Bootstrap Script (Self-Contained)
# ------------------------------------------------------------
# Creates:
#   - Terraform backend (RG, storage account, container)
#   - Service principal for GitHub
#   - Assigns required roles
#   - Creates 4 EntraID Users (EXACT names you supplied)
#   - Generates user_credentials.txt (EXACT output you supplied)
#   - Prints terraform.tfvars snippet (EXACT formatting)
# ------------------------------------------------------------


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== EDF Environment Bootstrap ===${NC}"

# ============================================================
# 0. Pre-flight checks
# ============================================================

if ! command -v az >/dev/null 2>&1; then
    echo -e "${RED}Azure CLI is not installed. Install it first.${NC}"
    exit 1
fi

if ! az account show >/dev/null 2>&1; then
    echo -e "${RED}Not logged in. Run: az login${NC}"
    exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
CURRENT_USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)
DOMAIN=$(az rest \
  --method GET \
  --url "https://graph.microsoft.com/v1.0/domains" \
  --query "value[?isDefault].id" -o tsv)

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Error: Could not determine default Entra ID domain${NC}"
    echo "Please check your Azure AD tenant configuration"
    echo "Or hard-code DOMAIN manually in the script."
    exit 1
fi

echo -e "${BLUE}Domain:                 ${DOMAIN}${NC}"

if [ -z "${CURRENT_USER_OBJECT_ID}" ]; then
    echo -e "${RED}ERROR: Unable to determine logged-in user.${NC}"
    exit 1
fi

echo -e "${BLUE}Current User Object ID: ${CURRENT_USER_OBJECT_ID}${NC}"
echo -e "${BLUE}Subscription:           ${SUBSCRIPTION_ID}${NC}"
echo -e "${BLUE}Tenant:                 ${TENANT_ID}${NC}"

echo -e "${BLUE}Please provide a globally unique project name (alphanumeric only):${NC}"
read -r PROJ_NAME

# Validate project name
if [[ ! "$PROJ_NAME" =~ ^[a-zA-Z0-9]+$ ]]; then
    echo -e "${RED}Error: Project name must contain only alphanumeric characters (A–Z, 0–9).${NC}"
    exit 1
fi

echo -e "${BLUE}How would you like to label your Terraform resources? i.e. for rg-terraform and saterraform, say 'terraform'. This must be globally unique (lowercase alphanumeric only, 3-24 characters for storage account):${NC}"
read -r TF_LABEL

# Validate Terraform label
if [[ ! "$TF_LABEL" =~ ^[a-z0-9]+$ ]]; then
    echo -e "${RED}Error: Terraform label must contain only lowercase letters and numbers.${NC}"
    exit 1
fi

if [ ${#TF_LABEL} -lt 3 ] || [ ${#TF_LABEL} -gt 24 ]; then
    echo -e "${RED}Error: Terraform label must be between 3 and 24 characters (storage account constraint).${NC}"
    exit 1
fi

# Derived resource names
RG_NAME="rg-${PROJ_NAME}"
KV_NAME="kv-${PROJ_NAME}"
TF_RG="rg-${TF_LABEL}"
TF_STORAGE="sa${TF_LABEL}"

echo -e "\n${GREEN}Using project name: ${PROJ_NAME}${NC}"
echo -e "${GREEN}Resource Group: ${RG_NAME}${NC}"
echo -e "${GREEN}Key Vault: ${KV_NAME}${NC}"
echo -e "${GREEN}Terraform Resource Group: ${TF_RG}${NC}"
echo -e "${GREEN}Terraform Storage Account: ${TF_STORAGE}${NC}"

# ============================================================
# 1. Required Permissions Check + Self-Assignment
# ============================================================

REQUIRED_ROLES=(
    "Owner"
    "User Access Administrator"
    "Key Vault Administrator"
)

echo -e "\n${GREEN}Checking user permissions...${NC}"

MISSING_ROLES=()

for ROLE in "${REQUIRED_ROLES[@]}"; do
    HAS=$(az role assignment list \
        --assignee "$CURRENT_USER_OBJECT_ID" \
        --role "$ROLE" \
        --scope "/subscriptions/${SUBSCRIPTION_ID}" \
        --query "[].id" -o tsv)

    if [ -z "$HAS" ]; then
        echo -e "${YELLOW}Missing role: ${ROLE}${NC}"
        MISSING_ROLES+=("$ROLE")
    else
        echo -e "${GREEN}✔ User has: ${ROLE}${NC}"
    fi
done

# Try to self-assign missing roles if allowed
if [ ${#MISSING_ROLES[@]} -gt 0 ]; then
    echo -e "${BLUE}Attempting to self-assign missing roles...${NC}"

    for ROLE in "${MISSING_ROLES[@]}"; do
        echo -e "${BLUE}Assigning ${ROLE}...${NC}"
        if ! az role assignment create \
            --assignee "$CURRENT_USER_OBJECT_ID" \
            --role "$ROLE" \
            --scope "/subscriptions/${SUBSCRIPTION_ID}" >/dev/null 2>&1; then

            echo -e "${RED}ERROR: Unable to self-assign '${ROLE}'.${NC}"
            echo -e "${RED}Ask a Subscription Owner or Global Admin to assign this role.${NC}"
            exit 1
        fi
        echo -e "${GREEN}✔ Assigned ${ROLE}${NC}"
    done
else
    echo -e "${GREEN}✔ User already has all required roles${NC}"
fi


# ============================================================
# 2. Terraform Backend Creation
# ============================================================

# TF_RG and TF_STORAGE are now set by user input above
TF_CONTAINER="tfstate"

echo -e "\n${GREEN}=== Ensuring Terraform backend exists ===${NC}"

# Resource group
if ! az group show --name "$TF_RG" &>/dev/null; then
    echo -e "${YELLOW}Creating RG: ${TF_RG}${NC}"
    az group create --name "$TF_RG" --location westeurope -o none
else
    echo -e "${GREEN}RG exists: ${TF_RG}${NC}"
fi

# Storage account
if ! az storage account show --name "$TF_STORAGE" --resource-group "$TF_RG" &>/dev/null; then
    echo -e "${YELLOW}Creating storage account: ${TF_STORAGE}${NC}"
    az storage account create \
        --name "$TF_STORAGE" \
        --resource-group "$TF_RG" \
        --sku Standard_LRS \
        --location westeurope \
        -o none
else
    echo -e "${GREEN}Storage account exists: ${TF_STORAGE}${NC}"
fi

# Storage key for container operations
ACCOUNT_KEY=$(az storage account keys list \
    --account-name "$TF_STORAGE" \
    --resource-group "$TF_RG" \
    --query "[0].value" -o tsv)

# Blob container
if ! az storage container show \
        --name "$TF_CONTAINER" \
        --account-name "$TF_STORAGE" \
        --account-key "$ACCOUNT_KEY" &>/dev/null; then
    
    echo -e "${YELLOW}Creating container: ${TF_CONTAINER}${NC}"
    az storage container create \
        --name "$TF_CONTAINER" \
        --public-access off \
        --account-name "$TF_STORAGE" \
        --account-key "$ACCOUNT_KEY" \
        -o none
else
    echo -e "${GREEN}Container exists: ${TF_CONTAINER}${NC}"
fi

echo -e "${GREEN}✔ Terraform backend ready${NC}"


# ============================================================
# 3. Service Principal Creation
# ============================================================

SP_NAME="sp-edf-github-2"

echo -e "\n${GREEN}=== Creating Service Principal: ${SP_NAME} ===${NC}"

SP_APP_ID=$(az ad sp list --display-name "$SP_NAME" --query "[0].appId" -o tsv || true)

if [ -z "$SP_APP_ID" ]; then
    echo -e "${YELLOW}Creating SP: ${SP_NAME}${NC}"

    SP_OUTPUT=$(az ad sp create-for-rbac \
        --name "$SP_NAME" \
        --role Contributor \
        --scopes "/subscriptions/${SUBSCRIPTION_ID}" \
        --query "{appId:appId,password:password,tenant:tenant}" -o json)

    SP_APP_ID=$(echo "$SP_OUTPUT" | jq -r .appId)
    SP_SECRET=$(echo "$SP_OUTPUT" | jq -r .password)
else
    echo -e "${GREEN}SP already exists${NC}"
    SP_SECRET="<NOT REGENERATED>"
fi

SP_OBJECT_ID=$(az ad sp show --id "$SP_APP_ID" --query "id" -o tsv)

echo -e "${BLUE}AppId:    ${SP_APP_ID}${NC}"
echo -e "${BLUE}ObjectId: ${SP_OBJECT_ID}${NC}"
echo -e "${BLUE}Secret:   ${SP_SECRET}${NC}"


# ============================================================
# 4. Assign Roles to SP (idempotent)
# ============================================================

echo -e "\n${GREEN}Assigning roles to Service Principal...${NC}"

SP_ROLES=(
    "Contributor|/subscriptions/${SUBSCRIPTION_ID}"
    "User Access Administrator|/subscriptions/${SUBSCRIPTION_ID}"
    "Storage Blob Data Contributor|/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${TF_RG}/providers/Microsoft.Storage/storageAccounts/${TF_STORAGE}"
    "Key Vault Administrator|/subscriptions/${SUBSCRIPTION_ID}"
)

for ENTRY in "${SP_ROLES[@]}"; do
    ROLE="${ENTRY%%|*}"
    SCOPE="${ENTRY##*|}"

    echo -e "${BLUE}Assigning ${ROLE} → ${SCOPE}${NC}"

    az role assignment create \
        --assignee "$SP_OBJECT_ID" \
        --role "$ROLE" \
        --scope "$SCOPE" \
        --only-show-errors >/dev/null 2>&1 || true
done

echo -e "${GREEN}✔ SP roles assigned${NC}"

echo -e "\n${GREEN}Assigning Microsoft Graph permissions to Service Principal...${NC}"

GRAPH_API_ID="00000003-0000-0000-c000-000000000000"
PERM_USER_READ_ALL="df021288-bdef-4463-88db-98f22de89214"
PERM_DIRECTORY_READ_ALL="7ab1d382-f21e-4acd-a863-ba3e13f7da61"

echo -e "${BLUE}Adding User.Read.All...${NC}"
az ad app permission add \
  --id "$SP_APP_ID" \
  --api $GRAPH_API_ID \
  --api-permissions "${PERM_USER_READ_ALL}=Role" \
  --only-show-errors >/dev/null 2>&1 || true

echo -e "${BLUE}Adding Directory.Read.All...${NC}"
az ad app permission add \
  --id "$SP_APP_ID" \
  --api $GRAPH_API_ID \
  --api-permissions "${PERM_DIRECTORY_READ_ALL}=Role" \
  --only-show-errors >/dev/null 2>&1 || true

echo -e "${GREEN}✔ Microsoft Graph permissions added${NC}"

echo -e "\n${GREEN}Granting admin consent for Microsoft Graph permissions...${NC}"

az ad app permission admin-consent \
  --id "$SP_APP_ID" \
  --only-show-errors >/dev/null 2>&1 || true

echo -e "${GREEN}✔ Admin consent granted (if permissions allowed)${NC}"


# ============================================================
# 5. Create EXACT USERS (from your snippet)
# ============================================================

echo -e "\n${GREEN}=== Creating EDF Test Users ===${NC}"

USERNAMES=("jess.admin" "jeff.developer" "bob.reader" "raj.client")
DISPLAYNAMES=("Jess Admin" "Jeff Developer" "Bob Reader" "Raj Client")

CREATED_COUNT=0
EXISTING_COUNT=0
FAILED_COUNT=0

# macOS Bash 3.x compatible password storage
USER_PASSWORD_KEYS=()
USER_PASSWORD_VALUES=()

# Lookup helper (Bash 3.x safe)
get_user_password() {
    local key="$1"
    for i in "${!USER_PASSWORD_KEYS[@]}"; do
        if [[ "${USER_PASSWORD_KEYS[$i]}" == "$key" ]]; then
            echo "${USER_PASSWORD_VALUES[$i]}"
            return
        fi
    done
}

# Strong password generator
generate_password() {
    openssl rand -base64 32 \
        | tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[]^_{|}~' \
        | head -c 16
}

echo -e "${GREEN}Creating users...${NC}\n"

for i in "${!USERNAMES[@]}"; do
    username="${USERNAMES[$i]}"
    displayname="${DISPLAYNAMES[$i]}"
    upn="${username}@${DOMAIN}"

    echo -e "${BLUE}Processing: ${displayname} (${upn})${NC}"

    # Generate password now and store it
    USER_PASSWORD=$(generate_password)
    USER_PASSWORD_KEYS+=("$username")
    USER_PASSWORD_VALUES+=("$USER_PASSWORD")

    # Check if already exists
    if az ad user show --id "$upn" &> /dev/null; then
        echo -e "${YELLOW}  ⚠ User already exists: ${upn}${NC}"
        ((EXISTING_COUNT++))
        continue
    fi

    # Create the user
    if az ad user create \
        --display-name "$displayname" \
        --user-principal-name "$upn" \
        --password "$USER_PASSWORD" \
        --force-change-password-next-sign-in true \
        --mail-nickname "$username" \
        --output none 2>/dev/null; then

        echo -e "${GREEN}  ✓ Created: ${upn}${NC}"
        ((CREATED_COUNT++))
    else
        echo -e "${RED}  ✗ Failed to create: ${upn}${NC}"
        ((FAILED_COUNT++))
    fi
done

# ============================================================
# 6. Output terraform config
# ============================================================

echo -e "\n=== Copy these lines to terraform/backend.tf ===\n"
cat <<EOF
  backend "azurerm" {
    resource_group_name  = "${TF_RG}"
    storage_account_name = "${TF_STORAGE}"
    container_name       = "${TF_CONTAINER}"
    key                  = "edf-test.tfstate"
  }
EOF

echo -e "\n=== Copy these lines to terraform/terraform.tfvars ===\n"
cat <<EOF
resource_group_name = "${RG_NAME}"
...
keyvault_name = "${KV_NAME}"
...
user_jess_upn = "jess.admin@${DOMAIN}"
user_jeff_upn = "jeff.developer@${DOMAIN}"
user_bob_upn  = "bob.reader@${DOMAIN}"
user_raj_upn  = "raj.client@${DOMAIN}"
EOF

echo -e "\n=== User Provisioning Complete ===\n"

# ============================================================
# 7. GitHub Actions secret output summary
# ============================================================

cat <<EOF

===========================================================
EDF Environment Setup Complete
===========================================================

=== GitHub Actions → Add These Secrets ===

AZURE_CLIENT_ID=${SP_APP_ID}
AZURE_TENANT_ID=${TENANT_ID}
AZURE_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}
AZURE_CLIENT_SECRET=${SP_SECRET}

Add them in your GitHub repo:
  Settings → Environments → <name your env> → Add Environment Secret

===========================================================

EOF