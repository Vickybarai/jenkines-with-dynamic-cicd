output "zone_id" {
  description = "Hosted zone ID (created or supplied)."
  value       = local.zone_id
}

output "zone_name" {
  description = "Hosted zone DNS name."
  value       = local.create_zone ? aws_route53_zone.this[0].name : local.zone_name
}

output "zone_arn" {
  description = "Hosted zone ARN when this module created the zone."
  value       = local.create_zone ? aws_route53_zone.this[0].arn : null
}

output "name_servers" {
  description = "Delegation name servers when this module created the zone. Point your registrar at these."
  value       = local.create_zone ? aws_route53_zone.this[0].name_servers : null
}

output "zone_created" {
  description = "True when this module created a new hosted zone."
  value       = local.create_zone
}

output "record_fqdns" {
  description = "Map of record keys (name-type) to FQDN."
  value       = { for key, record in aws_route53_record.this : key => record.fqdn }
}
