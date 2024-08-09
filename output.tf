output "user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.user_pool_client.id
}

output "rds_writer" {
  value = aws_rds_cluster.postgres.reader_endpoint
}

output "invoke_url" {
  value = "${aws_api_gateway_deployment.api_deployment.invoke_url}/fetch"
}

output "postgres_arn" {
  value = aws_rds_cluster.postgres.arn
}

output "db_name" {
  value = aws_rds_cluster.postgres.database_name
}

output secret_arn {
  value = aws_secretsmanager_secret.postgres_admin_secret.arn
}
