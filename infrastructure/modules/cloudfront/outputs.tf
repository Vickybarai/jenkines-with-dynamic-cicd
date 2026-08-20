output "bucket_id" {
  description = "S3 bucket name (ID)."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "S3 bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "bucket_regional_domain_name" {
  description = "S3 bucket regional domain name (CloudFront origin)."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "origin_access_control_id" {
  description = "Origin Access Control ID for the S3 origin."
  value       = aws_cloudfront_origin_access_control.this.id
}

output "distribution_id" {
  description = "CloudFront distribution ID (used for cache invalidation)."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = aws_cloudfront_distribution.this.arn
}

output "domain_name" {
  description = "CloudFront domain name to use as an alias target in Route 53."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID for CloudFront alias records."
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "distribution_domain_name" {
  description = "Same as domain_name; provided for clarity in root module wiring."
  value       = aws_cloudfront_distribution.this.domain_name
}
