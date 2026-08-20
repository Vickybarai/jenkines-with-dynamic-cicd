output "s3_bucket_name" {
  description = "S3 bucket for frontend build artifacts (sync dist/ here)."
  value       = module.cloudfront.bucket_id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN."
  value       = module.cloudfront.bucket_arn
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name (alias target for DNS)."
  value       = module.cloudfront.domain_name
}

output "cloudfront_distribution_id" {
  description = "Distribution ID for cache invalidation."
  value       = module.cloudfront.distribution_id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = module.cloudfront.distribution_arn
}

output "route53_zone_id" {
  description = "Route 53 hosted zone ID."
  value       = module.route53.zone_id
}

output "route53_name_servers" {
  description = "Name servers when this stack created a new zone."
  value       = module.route53.name_servers
}

output "dns_record_fqdns" {
  description = "FQDNs for DNS records created by this stack."
  value       = module.route53.record_fqdns
}
