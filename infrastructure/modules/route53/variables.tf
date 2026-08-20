variable "application" {
  description = "Application identifier used in tags."
  type        = string
}

variable "environment" {
  description = "Environment name used in tags."
  type        = string
}

variable "name_prefix" {
  description = "Override for resource name prefix in comments/tags. Defaults to {application}-{environment}."
  type        = string
  default     = null
}

variable "zone_name" {
  description = "DNS zone name to create — must be a domain you own. Required when zone_id is not set."
  type        = string
}

variable "zone_id" {
  description = "Existing hosted zone ID. When set, the module does not create a zone and uses this ID for records."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow Terraform to delete the hosted zone even when it contains records."
  type        = bool
  default     = false
}

variable "comment" {
  description = "Comment on the hosted zone when the module creates it."
  type        = string
  default     = null
}

variable "records" {
  description = <<-EOT
    DNS records to create. For CloudFront, use an alias record with the distribution domain_name and hosted_zone_id outputs.
    Each list entry must set either `alias` or `records` (for simple CNAME/TXT records).
  EOT
  type = list(object({
    name    = string
    type    = string
    ttl     = optional(number, 300)
    records = optional(list(string))
    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = optional(bool, false)
    }))
  }))
  default = []
}

variable "tags" {
  description = "Additional tags applied to the hosted zone when created."
  type        = map(string)
  default     = {}
}
