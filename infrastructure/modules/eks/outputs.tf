# outputs.tf — Values needed for kubectl, IRSA roles, and downstream modules

output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint URL."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.this.arn
}

output "cluster_security_group_id" {
  description = "Cluster security group created by EKS (attach/reference in network policies)."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  description = "Additional security group attached to worker nodes."
  value       = aws_security_group.node.id
}

output "node_group_arn" {
  description = "ARN of the managed node group."
  value       = aws_eks_node_group.this.arn
}

output "node_group_name" {
  description = "Name of the managed node group."
  value       = aws_eks_node_group.this.node_group_name
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN — use when creating IRSA roles for Kubernetes service accounts."
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL without https:// prefix (for trust policies)."
  value       = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

output "eks_cluster_version" {
  description = "Kubernetes version running on the control plane."
  value       = aws_eks_cluster.this.version
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA bundle for kubectl and CI/CD."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN used by the EKS control plane."
  value       = aws_iam_role.cluster.arn
}

output "cluster_admin_principal_arns" {
  description = "IAM principal ARNs granted cluster admin via EKS access entries."
  value       = local.cluster_admin_principal_arns
}

output "node_iam_role_arn" {
  description = "IAM role ARN used by worker nodes."
  value       = aws_iam_role.node.arn
}
