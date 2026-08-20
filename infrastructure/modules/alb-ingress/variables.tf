variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB security group is created."
  type        = string
}

variable "aws_region" {
  description = "AWS region for the load balancer controller."
  type        = string
}

variable "environment" {
  description = "Environment label for tags."
  type        = string
}

variable "project_name" {
  description = "Project label for tags."
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN for IRSA."
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL without https:// prefix."
  type        = string
}

variable "controller_namespace" {
  description = "Namespace for the AWS Load Balancer Controller."
  type        = string
  default     = "kube-system"
}

variable "controller_service_account_name" {
  description = "Kubernetes service account name for the controller."
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "controller_chart_version" {
  description = "Helm chart version for aws-load-balancer-controller (1.14.0 = controller v2.14.1)."
  type        = string
  default     = "1.14.0"
}

variable "install_controller" {
  description = "Install AWS Load Balancer Controller via Helm."
  type        = bool
  default     = true
}

variable "create_ingress" {
  description = "Create the Kubernetes Ingress resource."
  type        = bool
  default     = true
}

variable "alb_security_group_name_prefix" {
  description = "Name prefix for the ALB security group."
  type        = string
  default     = null
}

variable "allowed_inbound_cidrs" {
  description = "CIDR blocks allowed to reach the ALB on ports 80 and 443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ingress_name" {
  description = "Kubernetes Ingress resource name."
  type        = string
  default     = "cloudblitz-api-ingress"
}

variable "ingress_namespace" {
  description = "Kubernetes namespace for the API ingress."
  type        = string
  default     = "default"
}

variable "ingress_host" {
  description = "Hostname for the ingress rule."
  type        = string
}

variable "load_balancer_name" {
  description = "Fixed name for the internet-facing ALB."
  type        = string
  default     = "cdec-alpha-alb"
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in the same region as the EKS cluster."
  type        = string
}

variable "healthcheck_path" {
  description = "ALB health check path."
  type        = string
  default     = "/api/auth/health"
}

variable "ssl_policy" {
  description = "TLS policy for the HTTPS listener."
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

variable "ingress_paths" {
  description = "Path rules routed to backend services."
  type = list(object({
    path         = string
    service_name = string
    service_port = number
  }))
  default = [
    {
      path         = "/api/auth"
      service_name = "auth-service"
      service_port = 8081
    },
    {
      path         = "/api/courses"
      service_name = "course-service"
      service_port = 8082
    },
    {
      path         = "/api/enroll"
      service_name = "enrollment-service"
      service_port = 8083
    },
  ]
}

variable "additional_tags" {
  description = "Extra tags applied to AWS resources."
  type        = map(string)
  default     = {}
}
