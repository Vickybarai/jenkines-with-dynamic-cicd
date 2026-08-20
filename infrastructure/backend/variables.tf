# Shared

variable "aws_region" {
  description = "AWS region for VPC and EKS."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment label (dev, qa, prod)."
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for naming and tags."
  type        = string
  default     = "cdec"
}

variable "cluster_name" {
  description = "EKS cluster name (also used for VPC subnet tags)."
  type        = string
}

variable "additional_tags" {
  description = "Extra tags applied to VPC and EKS resources."
  type        = map(string)
  default     = {}
}

# VPC module

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (one per AZ)."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (one per AZ)."
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones for subnets."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for all private subnets (lower cost)."
  type        = bool
  default     = true
}

# EKS module

variable "kubernetes_version" {
  description = "EKS Kubernetes version. Null uses the regional default."
  type        = string
  default     = null
}

variable "node_instance_types" {
  description = "EC2 instance types for the node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "desired_size" {
  description = "Desired worker node count."
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum worker node count."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum worker node count."
  type        = number
  default     = 4
}

variable "disk_size" {
  description = "Node root volume size (GiB)."
  type        = number
  default     = 50
}

variable "cluster_endpoint_public_access" {
  description = "Enable public Kubernetes API endpoint."
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private Kubernetes API endpoint."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_cluster_autoscaler_tags" {
  description = "Tag node group for Cluster Autoscaler discovery."
  type        = bool
  default     = true
}

variable "cluster_admin_principal_arns" {
  description = "IAM user or role ARNs for kubectl. Must be arn:aws:iam::... — not assumed-role session ARNs from EC2."
  type        = list(string)
  default     = []
}

variable "cluster_admin_iam_role_names" {
  description = "IAM role names for EC2 instance profiles (e.g. Jenkins kubectl agent). Safer than copying sts get-caller-identity output from EC2."
  type        = list(string)
  default     = []
}

variable "include_caller_as_cluster_admin" {
  description = "Grant cluster admin to the IAM principal that runs Terraform apply."
  type        = bool
  default     = true
}

# ALB Ingress module

variable "enable_alb_ingress" {
  description = "Install AWS Load Balancer Controller and create the API ingress."
  type        = bool
  default     = true
}

variable "ingress_host" {
  description = "Hostname for the backend API ingress (e.g. api.example.com)."
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in the same region as EKS for the ALB HTTPS listener."
  type        = string
  default     = ""
}

variable "alb_name" {
  description = "Fixed name for the internet-facing ALB."
  type        = string
  default     = "cdec-alpha-alb"
}

variable "alb_allowed_inbound_cidrs" {
  description = "CIDR blocks allowed to reach the ALB on ports 80 and 443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ingress_paths" {
  description = "Ingress path rules for backend services."
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
