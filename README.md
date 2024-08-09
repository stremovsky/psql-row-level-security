# Terraform: PostgreSQL with Row-Level Security, Cognito, and Lambda Function

## Overview

The attached Terraform files creates the following AWS resources:

- **Secrets Manager**: Stores random database admin password in in AWS Secrets Manager.
- **RDS Cluster**: Creates an Aurora PostgreSQL database cluster with IAM authentication and Data API enabled.
- **Database Setup**: Executes SQL setup commands to initialize the database schema.
- **Cognito User Pool**: Creates a Cognito user pool for authentication.
- **Lambda Function**: Defines a Lambda function that interacts with the RDS cluster.
- **API Gateway**: Configures API Gateway to invoke the Lambda function via HTTP GET requests.

### Database Setup

* During deployment, Terraform uses the ``setup-db.sql`` file to configure row-level access to the **data_table**.
* The security group for database is configured to allow only from the default VPC CIDR.

## Cognito User Pool Setup

The Cognito service is configured with a custom user schema that includes the ``tenant_id`` field. Alternatively, this field can be stored directly in the database, which would require creating an additional table to manage user information.

The ``create-users.sh`` script creates test users in Cognito with different tenant_id values. This script is used further in the Testing section below.

## Lambda Function Overview

The sample Lambda function, located in ``src/lambda_function.py``, performs the following tasks:
1. Extracts the tenant_id from the user's Authorization HTTP header.
2. Connects to the Aurora PostgreSQL database using IAM authentication method.
3. Sets the database scope to the specific tenant_id with the command: cursor.execute("SET app.current_tenant TO %s", (tenant_id,)).
4. Selects and returns all records from the ``data_table`` that belong to the ``tenant_id``.

## Prerequisites

1. Download and install [Terraform](https://developer.hashicorp.com/terraform/install)
2. Ensure you have AWS CLI installed and configured with appropriate access keys

## Deployment

To deploy the resources, run the following commands:
```
# Create a zip file with the Lambda code
./prepare-files.sh

# Initialize and apply Terraform configuration
terraform init
terraform apply
```

## Testing

The test scripts authenticate users against AWS Cognito and call the Lambda function to verify that it returns data specific to the user's tenant.

1. Create test users in Cognito:
```
export AWS_DEFAULT_PROFILE='dev'
export AWS_DEFAULT_REGION='us-east-1'
./create-users.sh
```

2. Test the Lambda function with the created users:
```
./test-user1.sh
./test-user2.sh
```

For example output for user2:
```
Passing auth token to https://t4lwmg51sg.execute-api.us-east-1.amazonaws.com/prod/fetch
[[2, 2, "secret value for tenant 2"]]
```
