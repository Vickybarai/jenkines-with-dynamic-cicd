variable "aws_region" {
  description = "AWS region for S3 and regional resources. ACM for CloudFront must be in us-east-1."
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name used in tags and naming."
  type        = string
  default     = "dev"
}

variable "application" {
  description = "Application identifier for default tags."
  type        = string
  default     = "cdec-frontend"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name. Leave null to use {application}-{environment}-frontend."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow Terraform to delete the frontend bucket when it contains objects."
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Enable S3 versioning on the frontend bucket."
  type        = bool
  default     = false
}

variable "enable_spa_routing" {
  description = "Serve index.html for 403/404 responses (React client-side routing)."
  type        = bool
  default     = true
}

variable "cloudfront_aliases" {
  description = "Custom domain names for the distribution. When empty, dns_record_name is used as the alias if set."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1. Required if cloudfront_aliases is non-empty."
  type        = string
  default     = null
}

variable "dns_zone_name" {
  description = "Route 53 zone name to create (e.g. example.com). Required unless route53_zone_id is set."
  type        = string
}

variable "route53_zone_id" {
  description = "Existing hosted zone ID. When set, the module does not create a zone."
  type        = string
  default     = null
}

variable "dns_zone_force_destroy" {
  description = "Allow Terraform to delete the hosted zone when it contains records."
  type        = bool
  default     = false
}

variable "dns_record_name" {
  description = "FQDN for alias records to CloudFront (e.g. www.example.com). Leave empty to skip DNS records."
  type        = string
  default     = ""
}
