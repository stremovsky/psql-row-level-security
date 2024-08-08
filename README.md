# Terraform: PostgreSQL with row-level security, cognito and Lambda fucntion

The terraform file sets up the following:

1. An AWS PostgreSQL RDS instance
2. A Cognito User Pool
3. A lambda function to fetch records

Bash scripts provided to:
1. Create several user records in Cognito
2. The database configuration file that enables row-level security on a data table and loads sample data

3. A test function is provided that authenicates user agains AWS Cognito and calls the lambda function that returns data that belong to user tenant

Setup postgresql
```
export AWS_DEFAULT_PROFILE='dev'
export AWS_DEFAULT_REGION='us-east-1'
./setup-db.sh
```

## Prerequisites
1. Download and install [Terraform](https://developer.hashicorp.com/terraform/install)
2. Ensure you have AWS CLI installed and configured with appropriate access keys
3. Install Session Manager plugin for AWS cli: https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-macos-overview.html
3. Make sure to install postgresql client library: psql

I use the following commands to install on MACOS

```
brew install libpq
sudo ln -s `find /opt/homebrew/Cellar/libpq/ -name psql` /usr/local/bin/psql
sudo ln -s `find /opt/homebrew/Cellar/libpq/ -name pg_config` /usr/local/bin/pg_config
```

## How to use
1. Modify ``provider.tf`` file to ensure Terraform can work with your AWS access key. For example, you might use a custom AWS profile.
2. Install Terraform dependencies with ``terraform init`` command.
3. Run the ``./prepare-files.sh`` script to zip Python script files. The files will be saved into the hidden ``./files`` directory.
4. Run ``terraform apply`` to create all AWS infrastructure for this project: Lambda functions, API Gateway, and DynamoDB table.
5. Run ``./test-api-gw.sh`` to create a record in DynamoDB, dump it, and remove it.
6. Destroy infrustreucture with ``terraform destroy``

## All the steps together except the first one:
```
terraform init
./prepare-files.sh
terraform apply -auto-approve
./test-lambda.sh
terraform destroy -auto-approve
```

## Lambda function output
```
Public IP Address: 18.232.219.151
```
