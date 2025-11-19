EDF Technical Competency Task - Azure

1. Create a fork off of https://github.com/a-m-c-z/alex-test, or start a new repository with the provided files. Clone to your local machine.

2. Run `az login` in your terminal, using SSO to log in and select the subscription you wish to
create resources in for this task.

3. Set up pre-requisite infrastructure (ensuring you cd into project root directory):

chmod +x pre_requisite_setup.sh
./pre_requisite_setup.sh

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
