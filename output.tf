output "user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.user_pool_client.id
}

output "rds" {
  value = aws_db_instance.postgres.endpoint
}

output "invoke_url" {
  value = "${aws_api_gateway_deployment.api_deployment.invoke_url}/fetch"
}
