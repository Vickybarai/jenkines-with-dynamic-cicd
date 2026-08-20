# variables.tf — Inputs for the EKS module (VPC values usually come from modules/vpc outputs)

variable "cluster_name" {
  description = "Name of the EKS cluster (must be unique per region/account)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name)) && length(var.cluster_name) <= 100
    error_message = "cluster_name must start with a letter, use only alphanumeric characters and hyphens, and be at most 100 characters."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the control plane (e.g. 1.31). Leave null to use the latest version supported by EKS in this region."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID from the VPC module (or existing VPC)."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for worker nodes and (recommended) control plane ENIs."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "EKS requires subnets in at least 2 availability zones."
  }
}

variable "public_subnet_ids" {
  description = "Public subnet IDs — included in cluster vpc_config when load balancers need public subnet discovery."
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group (first type is primary)."
  type        = list(string)

  validation {
    condition     = length(var.node_instance_types) >= 1
    error_message = "Provide at least one instance type."
  }
}

variable "desired_size" {
  description = "Desired number of worker nodes (managed node group scaling)."
  type        = number

  validation {
    condition     = var.desired_size >= 0
    error_message = "desired_size must be >= 0."
  }
}

variable "min_size" {
  description = "Minimum number of worker nodes for autoscaling."
  type        = number

  validation {
    condition     = var.min_size >= 0
    error_message = "min_size must be >= 0."
  }
}

variable "max_size" {
  description = "Maximum number of worker nodes for autoscaling."
  type        = number
}

variable "disk_size" {
  description = "Root volume size (GiB) for worker nodes."
  type        = number
  default     = 50

  validation {
    condition     = var.disk_size >= 20
    error_message = "disk_size must be at least 20 GiB."
  }
}

variable "environment" {
  description = "Environment label (dev, staging, prod)."
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming and tags."
  type        = string
}

variable "cluster_endpoint_public_access" {
  description = "Allow the Kubernetes API to be reached from the internet (restrict with CIDRs in production)."
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Allow the Kubernetes API to be reached from within the VPC (required for private-only access patterns)."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public API endpoint. Use your office/VPN CIDRs in production — not 0.0.0.0/0."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "Control plane log types shipped to CloudWatch Logs."
  type        = list(string)
  default = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]
}

variable "node_max_unavailable_percentage" {
  description = "Maximum percentage of nodes unavailable during a rolling update (1–100)."
  type        = number
  default     = 33

  validation {
    condition     = var.node_max_unavailable_percentage >= 1 && var.node_max_unavailable_percentage <= 100
    error_message = "node_max_unavailable_percentage must be between 1 and 100."
  }
}

variable "enable_cluster_autoscaler_tags" {
  description = "Add tags so Kubernetes Cluster Autoscaler can discover this node group (optional if you only use managed scaling)."
  type        = bool
  default     = true
}

variable "additional_tags" {
  description = "Extra tags merged into cluster, node group, and IAM resources."
  type        = map(string)
  default     = {}
}

variable "cluster_authentication_mode" {
  description = "EKS cluster authentication mode. Use API_AND_CONFIG_MAP when migrating an existing cluster; API for new clusters only."
  type        = string
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["API", "API_AND_CONFIG_MAP", "CONFIG_MAP"], var.cluster_authentication_mode)
    error_message = "cluster_authentication_mode must be API, API_AND_CONFIG_MAP, or CONFIG_MAP."
  }
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Grant cluster admin to the IAM principal that creates the cluster. Only effective at cluster creation; leave false for existing clusters."
  type        = bool
  default     = false
}

variable "cluster_admin_principal_arns" {
  description = "IAM user or role ARNs granted AmazonEKSClusterAdminPolicy. Use arn:aws:iam::...:role/NAME — not assumed-role session ARNs from sts get-caller-identity on EC2."
  type        = list(string)
  default     = []
}

variable "cluster_admin_iam_role_names" {
  description = "IAM role names (without path) for EC2 instance profiles / Jenkins agents. ARNs are built as arn:aws:iam::ACCOUNT:role/NAME."
  type        = list(string)
  default     = []
}

variable "include_caller_as_cluster_admin" {
  description = "Grant cluster admin to the IAM principal running Terraform (e.g. Jenkins aws-frontend-terraform user)."
  type        = bool
  default     = true
}
