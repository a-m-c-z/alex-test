EDF Technical Competency Task - Azure

1. Create a fork off of https://github.com/a-m-c-z/alex-test, or start a new repository with the provided files. Clone to your local machine.

2. Run `az login` in your terminal, using SSO to log in and select the subscription you wish to
create resources in for this task.

3. Set up pre-requisite infrastructure (ensuring you cd into project root directory):

chmod +x utilities/pre_requisite_setup.sh
./utilities/pre_requisite_setup.sh

NOTE: The person running this script will need full governance access inside the target subscription.

This will:
- Ensure, after running `az login`, that the user has the necessary permissions to perform necessry actions for this task.
- Set up Terraform state file blob storage in Azure.
- Set up a Service Principal for GitHub Actions integration and assign it necessary permissions to create and modify Azure resources.
- NOTE: This will provide you with the Client Secret for GitHub Actions - please securely make note of it as you will not be able to retrieve it once the terminal is closed.
- Create the mock users specified in the task.
- Provide you with copy and paste config for Terraform files and GitHub Actions. Please ensure you follow these instructions.

4. Ensuring you have created a feature branch off main, and that you have stored the Service Principal credentials in your GitHub Environment, edit terraform/terraform.tfvars with your project variables. Please note Storage Account names must only be lowercase and alphanumeric characters.

5. Ensure requirements are up to date. This project using pip-compile-multi for dependency management. In terminal, run `pip install pip-compile-multi` if you do not already have it installed. If/when it is installed, run:

pip freeze
pip-compile-multi

To populate the requirements files with up to date and compatible dependencies. Assuming you have activated a virtual environment, optionally run the following if you want to work on the scripts:

pip install -r requirements/base.txt <- Libraries used by Azure Function
pip install -r requirements/requirements-dev.txt <- Libraries used by unit tests

To push these updates to the Azure Function requirements, perform:

cd function
rm requirements.txt
ln -s ../requirements/base.txt requirements.txt

This will create a symlink between base.txt and requirements.txt

6. Commit and push branch to Git and create pull request. This should start code quality checks, and perform Terraform Plan to test viability of code deployment into Azure.

7. If the checks pass, merge into the main branch. This should repeat the same checks, followed by Terraform Apply, then uploading the Azure Function script to the Function App.

8. Deploy the mock data csv into the preprocess blob storage. This can be done manually via the GUI, or by running 

chmod +x utilities/upload_mock_data.sh
./utilities/upload_mock_data.sh

It will prompt you for your resource group, which is the same as the one provided as resource_group_name in terraform/terraform.tfvars.

9. Find your function app (name provided at function_app_name) in Azure. You may need to wait for a few minutes before refreshing it and seeing the Azure Function there. Try restarting it in the GUI if needed, then refreshing again. You should see a function called 'filter_sql_servers'.

10. Click it, and click 'Test/Run'. Leave the HTTP Method as 'POST' and set the Key to 'default (Function key)' and click run. You may be given a warning to add https://portal.azure.com to CORS. Follow the link to do so and click 'Save'. Give it a moment for the change to take place, navigate back to your function and click 'Test/Run', following the same steps as above.

You should read 

Report generated successfully: sql_servers_report_20251119_142741.xlsx
Total SQL Server VMs: 45
File is password-protected using Key Vault secret

NOTE: You can also trigger the function from the command line using:

FUNC_NAME=<function_app_name>
FUNC_KEY=$(az functionapp function keys list \
  --name $FUNC_NAME \
  --resource-group rg-edftest \
  --function-name filter_sql_servers \
  --query "default" -o tsv)

curl -X POST "https://${FUNC_NAME}.azurewebsites.net/api/filter_sql_servers?code=${FUNC_KEY}"

11. Test the output by looking for the Excel Spreadsheet in post-processing blob store set at postprocess_storage_name in terraform/terraform.tfvars. Download it, and open it with the password set in the Key Vault. Note that the password in password.txt will not work in lieu of a more secure option. 

You shouldn't need additional privileges to access the Key Vault as it is already provisioned in the pre-requisite script. If you need to elevate your privileges to access Key Vault, run

CURRENT_USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
SUBSCRIPTION_ID=<subscription_id>
RG_NAME=<resource_group_name>
KV_NAME=<keyvault_name>
az role assignment create \
  --assignee "$CURRENT_USER_OBJECT_ID" \
  --role "Key Vault Secrets Officer" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.KeyVault/vaults/${KV_NAME}"