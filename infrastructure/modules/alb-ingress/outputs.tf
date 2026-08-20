output "alb_security_group_id" {
  description = "Security group ID attached to the internet-facing ALB."
  value       = aws_security_group.alb.id
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN used by the AWS Load Balancer Controller service account."
  value       = aws_iam_role.load_balancer_controller.arn
}

output "load_balancer_controller_policy_arn" {
  description = "IAM policy ARN for the AWS Load Balancer Controller."
  value       = aws_iam_policy.load_balancer_controller.arn
}

output "ingress_name" {
  description = "Kubernetes Ingress resource name."
  value       = var.create_ingress ? kubernetes_ingress_v1.api[0].metadata[0].name : null
}

output "ingress_namespace" {
  description = "Kubernetes namespace of the API ingress."
  value       = var.ingress_namespace
}

output "ingress_host" {
  description = "Hostname configured on the ingress."
  value       = var.ingress_host
}
