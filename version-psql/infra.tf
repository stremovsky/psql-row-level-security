resource "aws_security_group" "postgres_sg" {
  name = "postgres-sg"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier              = "postgresql-db"
  engine                  = "postgres"
  instance_class          = "db.t3.micro"
  allocated_storage       = 10
  db_name                 = "tenantdb"
  username                = "dbadmin"
  password                = "adminpassword"
  skip_final_snapshot     = true
  publicly_accessible     = false
  apply_immediately       = true
  iam_database_authentication_enabled = true
  vpc_security_group_ids  = [aws_security_group.postgres_sg.id]
}

data "aws_db_subnet_group" "example" {
  name = aws_db_instance.postgres.db_subnet_group_name
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
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
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
        Effect   = "Allow"
        Resource = [
          "arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.postgres.identifier}/rds_iam_user",
          "arn:aws:rds-db:*:*:dbuser:*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn  = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
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
      DB_HOST     = aws_db_instance.postgres.endpoint
      DB_NAME     = aws_db_instance.postgres.db_name
      DB_USER     = "rds_iam_user"
      REGION      = var.region
    }
  }
  vpc_config {
    subnet_ids          = data.aws_db_subnet_group.example.subnet_ids
    security_group_ids  = [aws_security_group.lambda_sg.id]
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
  function_name = aws_lambda_function.fetch_records.function_name
  maximum_retry_attempts = 0
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
  path_part    = "fetch"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.fetch_records.arn}/invocations"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_method.method,
    aws_api_gateway_integration.integration
  ]
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}
