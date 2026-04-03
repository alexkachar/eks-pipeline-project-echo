output "db_endpoint" {
  value       = aws_db_instance.this.endpoint
  description = "RDS endpoint (host:port)"
}

output "db_address" {
  value       = aws_db_instance.this.address
  description = "RDS hostname"
}

output "db_port" {
  value       = aws_db_instance.this.port
  description = "RDS port"
}

output "db_identifier" {
  value       = aws_db_instance.this.identifier
  description = "RDS instance identifier"
}

output "db_security_group_id" {
  value       = aws_security_group.rds.id
  description = "Security group ID attached to the RDS instance"
}

output "ssm_parameter_paths" {
  value = {
    db_host     = aws_ssm_parameter.db_host.name
    db_port     = aws_ssm_parameter.db_port.name
    db_name     = aws_ssm_parameter.db_name.name
    db_user     = aws_ssm_parameter.db_user.name
    db_password = aws_ssm_parameter.db_password.name
  }
  description = "SSM Parameter Store paths for all DB credentials"
}
