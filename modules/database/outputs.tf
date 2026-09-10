output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.app.id
}

output "db_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.app.address
}

output "db_port" {
  description = "RDS database port"
  value       = aws_db_instance.app.port
}

