variable "access_password" {
  type        = string
  default     = "icanreadgood"
  description = "Value of the k parameter in the phone link. 8-64 letters, numbers, hyphens, or underscores."

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{8,64}$", var.access_password))
    error_message = "access_password must be 8-64 characters and use only letters, numbers, hyphens, and underscores."
  }
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Region for the private bucket. The phone link is served from CloudFront and is not tied to this region."
}
