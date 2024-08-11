# Generate a random password
resource "random_password" "postgres_admin_password" {
  length  = 16
  special = true
  override_special = "_%@"
}

# Create a Secrets Manager secret
resource "aws_secretsmanager_secret" "postgres_admin_secret" {
  name = "postgres_admin_password"
}

# Store the random password in the secret
resource "aws_secretsmanager_secret_version" "postgres_admin_secret_version" {
  secret_id = aws_secretsmanager_secret.postgres_admin_secret.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.postgres_admin_password.result
  })
  lifecycle {
    prevent_destroy = true
    create_before_destroy = true
  }
}

data "aws_vpc" "default" {
  default = true
}

# Security Group for database access
resource "aws_security_group" "postgres_sg" {
  name = "postgres-sg"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create database instance witout public IP
resource "aws_rds_cluster" "postgres" {
  cluster_identifier = "postgresql-cluster"
  engine             = "aurora-postgresql"
  #engine_version          = "13.6"
  master_username        = "dbadmin"
  master_password        = random_password.postgres_admin_password.result
  database_name          = "tenantdb"
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
  skip_final_snapshot    = true

  # Enable IAM Database Authentication
  iam_database_authentication_enabled = true

  # Enable Data API
  enable_http_endpoint = true

  tags = {
    Name = "postgresql-cluster"
  }
}

resource "aws_rds_cluster_instance" "writer" {
  count              = 1
  identifier         = "aurora-pg-writer-${count.index}"
  cluster_identifier = aws_rds_cluster.postgres.cluster_identifier
  engine             = "aurora-postgresql"
  instance_class     = "db.r5.large"
  depends_on = [
    aws_rds_cluster.postgres
  ]
}

#resource "aws_rds_cluster_instance" "readers" {
#  count              = 0
#  identifier         = "aurora-pg-reader-${count.index}"
#  cluster_identifier = aws_rds_cluster.postgres.cluster_identifier
#  engine             = "aurora-postgresql"
#  instance_class     = "db.r5.large"
#  depends_on = [
#    aws_rds_cluster.postgres
#  ]
#}

data "aws_db_subnet_group" "example" {
  name = aws_rds_cluster.postgres.db_subnet_group_name
}

# Adding new step to wait for database to be fully available
resource "null_resource" "wait_for_rds" {
  depends_on = [aws_rds_cluster_instance.writer]
  provisioner "local-exec" {
    command = "aws rds wait db-instance-available --db-instance-identifier ${aws_rds_cluster_instance.writer[0].id}"
  }
}

resource "null_resource" "db_setup" {
  depends_on = [null_resource.wait_for_rds]
  triggers = {
    file = filesha1("setup-db.sql")
  }
  provisioner "local-exec" {
    command = <<-EOF
      while read line; do
        echo "$line"
        aws rds-data execute-statement --resource-arn "$DB_ARN" --database  "$DB_NAME" --secret-arn "$SECRET_ARN" --sql "$line"
      done  < <(awk 'BEGIN{RS=";\n"}{gsub(/\n/,""); if(NF>0) {print $0";"}}' setup-db.sql)
      EOF
    environment = {
      DB_ARN     = aws_rds_cluster.postgres.arn
      DB_NAME    = aws_rds_cluster.postgres.database_name
      SECRET_ARN = aws_secretsmanager_secret.postgres_admin_secret.arn
    }
    interpreter = ["bash", "-c"]
  }
}

resource "aws_cognito_user_pool" "user_pool" {
  name = "user-pool"
  schema {
    attribute_data_type = "String"
    name                = "tenant_id"
    required            = false
    mutable             = true
  }
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "user-pool-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  # Prevent the client from having a secret
  generate_secret = false
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rds-db:connect"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_rds_cluster.postgres.cluster_resource_id}/rds_iam_user",
          "arn:aws:rds-db:*:*:dbuser:*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_rds_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSDataFullAccess"
}

resource "aws_security_group" "lambda_sg" {
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lambda_function" "fetch_records" {
  filename         = ".files/lambda_function.zip"
  source_code_hash = filebase64sha256(".files/lambda_function.zip")
  function_name    = "fetchRecords"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.10"
  timeout          = 10
  environment {
    variables = {
      DB_HOST = aws_rds_cluster.postgres.reader_endpoint
      DB_NAME = aws_rds_cluster.postgres.database_name
      DB_USER = "rds_iam_user"
      REGION  = data.aws_region.current.name
    }
  }
  vpc_config {
    subnet_ids         = data.aws_db_subnet_group.example.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

resource "aws_lambda_permission" "allow_cognito_invoke" {
  statement_id  = "AllowInvokeFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_records.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.user_pool.arn
}

resource "aws_lambda_function_event_invoke_config" "invoke_config" {
  function_name                = aws_lambda_function.fetch_records.function_name
  maximum_retry_attempts       = 0
  maximum_event_age_in_seconds = 60
}

resource "aws_lambda_permission" "allow_invoke" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_records.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_rest_api" "api" {
  name        = "fetch-api"
  description = "API for invoking fetch data Lambda"
}

resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "fetch"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.fetch_records.arn}/invocations"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_method.method,
    aws_api_gateway_integration.integration
  ]
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}
