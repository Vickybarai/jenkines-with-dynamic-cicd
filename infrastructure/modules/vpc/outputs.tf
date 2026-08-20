# outputs.tf — Values consumers need when creating the EKS cluster

output "vpc_id" {
  description = "ID of the VPC — pass to aws_eks_cluster.vpc_config and node groups."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC (useful for security group rules)."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs — use for internet-facing load balancers and NAT."
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs — use for EKS node groups and internal LBs."
  value       = [for s in aws_subnet.private : s.id]
}

output "public_subnet_ids_by_az" {
  description = "Map of AZ => public subnet ID (handy for explicit AZ placement)."
  value       = { for az, s in aws_subnet.public : az => s.id }
}

output "private_subnet_ids_by_az" {
  description = "Map of AZ => private subnet ID."
  value       = { for az, s in aws_subnet.private : az => s.id }
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs (one or more depending on single_nat_gateway)."
  value       = [for ng in aws_nat_gateway.this : ng.id]
}

output "nat_gateway_id" {
  description = "Primary NAT Gateway ID (first when multiple exist) — backward-compatible single value."
  value       = values(aws_nat_gateway.this)[0].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID attached to this VPC."
  value       = aws_internet_gateway.this.id
}

output "availability_zones" {
  description = "AZs used by subnets — pass to EKS for multi-AZ node groups."
  value       = var.availability_zones
}
