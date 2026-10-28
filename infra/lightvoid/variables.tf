variable "domain_name" {
  type        = string
  default     = "lightvoid.app"
  description = "Apex domain for app-store contact email and per-app subdomains."
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Region for SES inbound, Lambda, and S3. CloudFront and ACM use us-east-1 as required."
}

variable "support_mailbox" {
  type        = string
  default     = "support"
  description = "Local part for the public support address (e.g. support → support@lightvoid.app). Inbound mail uses a domain-wide SES rule; no extra DNS for this mailbox."
}

variable "inbound_forward_to" {
  type        = string
  description = "Personal inbox that receives mail sent to any address @domain (hello@, support@, etc.). Verified automatically for SES sandbox."
}
