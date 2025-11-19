# EDF Technical Competency Task - Azure

## Overview
This guide walks through setting up an Azure-based SQL Server monitoring solution with automated report generation using Terraform, GitHub Actions, and Azure Functions.

---

## Prerequisites
- Azure CLI installed and configured
- Git installed
- Python 3.x with pip
- Full governance access to target Azure subscription
- GitHub account with repository access

---

## Setup Instructions

### 1. Repository Setup
Create a fork of the [starter repository](https://github.com/a-m-c-z/alex-test) or start a new repository with the provided files, then clone it to your local machine.

### 2. Azure Authentication
Log in to Azure using SSO and select your target subscription:
```bash
az login
```

### 3. Pre-requisite Infrastructure Setup
Navigate to the project root directory and run the setup script and follow the prompts.
```bash
chmod +x pre_requisite_setup.sh
./pre_requisite_setup.sh
```

**Note:** You must have full governance access in the target subscription.

This script will:
- Verify your Azure permissions for the task
- Create Terraform state file blob storage in Azure
- Set up a Service Principal for GitHub Actions with necessary permissions (optional)
- **Important:** Display the Client Secret for GitHub Actions - **save this securely** as it cannot be retrieved later
- Create mock users as specified in the task
- Provide configuration snippets for Terraform files and GitHub Actions - follow these instructions carefully

### 4. Configure Terraform Variables
1. Create a feature branch from `main`
2. Store the Service Principal credentials in your GitHub Environment
3. Edit `terraform/terraform.tfvars` with your project variables

**Note:** Storage Account names must be lowercase alphanumeric characters only.

### 5. Dependency Management
This project uses `pip-compile-multi` for dependency management.

#### Install pip-compile-multi
```bash
pip install pip-compile-multi
```

#### Update dependencies
```bash
pip freeze
pip-compile-multi
```

#### Optional: Install dependencies for local development
If working with a virtual environment:
```bash
# Libraries used by Azure Function
pip install -r requirements/base.txt

# Libraries used by unit tests
pip install -r requirements/requirements-dev.txt
```

#### Link requirements to Azure Function
```bash
cd function
rm requirements.txt
ln -s ../requirements/base.txt requirements.txt
```
This creates a symlink between `base.txt` and `requirements.txt`.

### 6. Deploy Infrastructure
1. Commit and push your feature branch to Git
2. Create a pull request
3. This triggers:
   - Code quality checks
   - Terraform Plan to validate deployment

### 7. Apply Changes
Once checks pass:
1. Merge into the `main` branch
2. This triggers:
   - Repeat of all checks
   - Terraform Apply
   - Upload of Azure Function script to Function App

### 8. Upload Mock Data
Deploy the mock data CSV to the preprocess blob storage.

**Option A: Manual upload via Azure Portal GUI**

**Option B: Script upload**
```bash
chmod +x utilities/upload_mock_data.sh
./utilities/upload_mock_data.sh
```
The script will prompt for your resource group name (same as `resource_group_name` in `terraform/terraform.tfvars`).

### 9. Locate Azure Function
1. Navigate to your Function App in Azure Portal (name from `function_app_name` variable)
2. Wait a few minutes, then refresh
3. If the function doesn't appear, restart the Function App in the GUI and refresh again
4. You should see a function called `filter_sql_servers`

### 10. Test the Function

#### Via Azure Portal
1. Click on `filter_sql_servers`
2. Click **Test/Run**
3. Leave HTTP Method as **POST**
4. Set Key to **default (Function key)**
5. Click **Run**

**CORS Warning:** If prompted to add `https://portal.azure.com` to CORS, follow the link, add it, and click **Save**. Wait a moment, then navigate back and repeat the test steps.

**Expected output:**
```
Report generated successfully: sql_servers_report_20251119_142741.xlsx
Total SQL Server VMs: 45
File is password-protected using Key Vault secret
```

#### Via Command Line
```bash
FUNC_NAME=<function_app_name>
FUNC_KEY=$(az functionapp function keys list \
  --name $FUNC_NAME \
  --resource-group rg-edftest \
  --function-name filter_sql_servers \
  --query "default" -o tsv)

curl -X POST "https://${FUNC_NAME}.azurewebsites.net/api/filter_sql_servers?code=${FUNC_KEY}"
```

### 11. Verify Output
1. Navigate to the post-processing blob storage (set in `postprocess_storage_name` in `terraform/terraform.tfvars`)
2. Download the generated Excel spreadsheet
3. Open it using the password stored in Azure Key Vault

**Note:** The password in `password.txt` will not work - retrieve it from Key Vault instead.

#### Elevate Key Vault Access (if needed)
```bash
CURRENT_USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
SUBSCRIPTION_ID=<subscription_id>
RG_NAME=<resource_group_name>
KV_NAME=<keyvault_name>

az role assignment create \
  --assignee "$CURRENT_USER_OBJECT_ID" \
  --role "Key Vault Secrets Officer" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.KeyVault/vaults/${KV_NAME}"
```

---

## Troubleshooting
- If the Function App doesn't show functions, wait a few minutes and refresh, or restart the app
- Ensure CORS is configured correctly if testing via Azure Portal
- Verify Service Principal credentials are correctly stored in GitHub Environment
- Check that all resource names follow Azure naming conventions (e.g., lowercase alphanumeric for Storage Accounts)

---

## Architecture Overview

### Components
- **Terraform**: Infrastructure as Code for Azure resource provisioning
- **GitHub Actions**: CI/CD pipeline for automated deployment
- **Azure Function**: Serverless compute for SQL Server filtering logic
- **Azure Blob Storage**: Data storage for input CSV and output Excel reports
- **Azure Key Vault**: Secure storage for sensitive credentials (Excel password)

### Workflow
1. Mock CSV data uploaded to preprocessing storage
2. Azure Function triggered via HTTP POST
3. Function reads CSV, filters SQL Server VMs
4. Generates password-protected Excel report
5. Stores report in post-processing storage
6. Password retrieved from Key Vault for file access
