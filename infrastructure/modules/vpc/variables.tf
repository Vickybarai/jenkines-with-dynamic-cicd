# variables.tf — Module inputs with validation
#
# Validation runs at `terraform plan` time and catches misconfiguration
# before anything is created in AWS.

variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g. 10.0.0.0/16). Must be large enough for public and private subnets."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets. Length must match availability_zones."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "EKS requires at least 2 public subnets (one per AZ) for load balancer high availability."
  }
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets. Length must match availability_zones."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "EKS requires at least 2 private subnets (one per AZ) for worker nodes across zones."
  }
}

variable "availability_zones" {
  description = "List of AZ names (e.g. [\"ap-south-1a\", \"ap-south-1b\"]). Subnets are created one per AZ."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Provide at least 2 availability zones for EKS control plane and node spread."
  }
}

variable "cluster_name" {
  description = "EKS cluster name — used in kubernetes.io/cluster/<name> subnet tags so the AWS Load Balancer Controller can discover subnets."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name)) && length(var.cluster_name) <= 100
    error_message = "cluster_name must start with a letter, contain only alphanumeric characters and hyphens, and be at most 100 characters."
  }
}

variable "environment" {
  description = "Environment label (e.g. dev, staging, prod) — applied to all resources for cost and operations."
  type        = string
}

variable "project_name" {
  description = "Project or team name — used in resource naming and tags."
  type        = string
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC. Required for EKS nodes to resolve internal endpoints."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS resolution in the VPC. Required for EKS and private service discovery."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "If true, create one NAT Gateway (cost-effective). If false, one NAT per AZ (higher availability, higher cost)."
  type        = bool
  default     = true
}

variable "additional_tags" {
  description = "Extra tags merged into every resource (e.g. cost-center, owner)."
  type        = map(string)
  default     = {}
}
