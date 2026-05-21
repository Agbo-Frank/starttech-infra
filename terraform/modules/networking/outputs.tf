output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

output "lb_sg_id" {
  description = "ID of the load balancer security group"
  value       = aws_security_group.lb_sg.id
}

output "web_sg_id" {
  description = "ID of the web/backend security group"
  value       = aws_security_group.web_sg.id
}

output "cache_sg_id" {
  description = "ID of the ElastiCache security group"
  value       = aws_security_group.cache_sg.id
}

output "nat_eip_public_ips" {
  description = "Public IPs of the NAT gateways (add these to MongoDB Atlas IP whitelist)"
  value       = [for eip in aws_eip.nat_eips : eip.public_ip]
}
