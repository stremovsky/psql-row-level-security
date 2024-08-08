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

  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
}

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

resource "aws_cognito_user_pool" "user_pool" {
  name = "user-pool"
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "user-pool-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id
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
          "arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.postgres.db_name}/rds_iam_user"
        ]
      }
    ]
  })
}

resource "aws_lambda_function" "fetch_records" {
  filename         = ".files/lambda_function.zip"
  function_name    = "fetchRecords"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.10"
  environment {
    variables = {
      DB_HOST     = aws_db_instance.postgres.endpoint
      DB_NAME     = aws_db_instance.postgres.db_name
      DB_USER     = "rds_iam_user"
      REGION      = var.region
    }
  }
}

resource "aws_lambda_permission" "allow_cognito_invoke" {
  statement_id  = "AllowInvokeFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_records.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.user_pool.arn
}
