output "phone_url" {
  description = "Open this on your phone and save this link. The address bar drops the password after the first load."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}/?${local.access_param}=${var.access_password}"
}

output "bucket" {
  description = "Private bucket that holds the built site."
  value       = aws_s3_bucket.site.id
}

output "distribution_id" {
  description = "CloudFront distribution that serves the phone link."
  value       = aws_cloudfront_distribution.site.id
}
