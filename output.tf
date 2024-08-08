output "user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "rds" {
  value = aws_db_instance.postgres.endpoint
}
