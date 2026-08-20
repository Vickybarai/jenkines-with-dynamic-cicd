# VPC

output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

# EKS

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA."
  value       = module.eks.oidc_provider_arn
}

output "node_group_name" {
  description = "Managed node group name."
  value       = module.eks.node_group_name
}

# ALB Ingress

output "alb_security_group_id" {
  description = "Security group ID attached to the API ALB."
  value       = var.enable_alb_ingress ? module.alb_ingress[0].alb_security_group_id : null
}

output "ingress_host" {
  description = "API ingress hostname."
  value       = var.enable_alb_ingress ? module.alb_ingress[0].ingress_host : null
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller."
  value       = var.enable_alb_ingress ? module.alb_ingress[0].load_balancer_controller_role_arn : null
}
