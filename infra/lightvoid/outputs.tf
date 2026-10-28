output "domain_name" {
  value       = var.domain_name
  description = "Apex domain."
}

output "name_servers" {
  description = "Route 53 name servers for lightvoid.app."
  value       = data.aws_route53_zone.main.name_servers
}

output "support_email" {
  description = "Use in App Store / Play Console contact fields."
  value       = "${var.support_mailbox}@${var.domain_name}"
}

output "philoscroll_privacy_url" {
  description = "Privacy policy URL for PhiloScroll."
  value       = "https://philoscroll.${var.domain_name}/privacy.html"
}

output "philoscroll_site_url" {
  value = "https://philoscroll.${var.domain_name}/"
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.site.domain_name
}
