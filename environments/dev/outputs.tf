output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "nat_gateway_ids" {
  value = module.networking.nat_gateway_ids
}

#Security group
output "alb_security_group_id" {
  value = module.security.alb_security_group_id
}

output "ec2_security_group_id" {
  value = module.security.ec2_security_group_id
}

output "rds_security_group_id" {
  value = module.security.rds_security_group_id
}


#alb 
output "alb_dns_name" {
  value = module.load_balancer.alb_dns_name
}

output "alb_arn" {
  value = module.load_balancer.alb_arn
}



#database
output "db_endpoint" {
  value = module.database.db_endpoint
}

output "db_port" {
  value = module.database.db_port
}


#cloudwatch 
output "cpu_alarm_name" {
  value = module.monitoring.cpu_alarm_name
}