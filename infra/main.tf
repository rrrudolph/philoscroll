# From the repo root:
#   npm run build
#   terraform -chdir=infra init
#   terraform -chdir=infra apply
# The phone link is the phone_url output.

data "aws_caller_identity" "current" {}

locals {
  access_param  = "k"
  access_cookie = "philo"
  dist_dir      = "${path.module}/../dist"
  dist_ready    = fileexists("${local.dist_dir}/index.html")
  site_files    = local.dist_ready ? fileset(local.dist_dir, "**") : toset([])
  content_types = {
    css         = "text/css; charset=utf-8"
    html        = "text/html; charset=utf-8"
    js          = "text/javascript; charset=utf-8"
    json        = "application/json; charset=utf-8"
    map         = "application/json; charset=utf-8"
    svg         = "image/svg+xml"
    woff        = "font/woff"
    woff2       = "font/woff2"
    png         = "image/png"
    jpg         = "image/jpeg"
    jpeg        = "image/jpeg"
    webp        = "image/webp"
    ico         = "image/x-icon"
    txt         = "text/plain; charset=utf-8"
    webmanifest = "application/manifest+json"
  }
}

resource "terraform_data" "site_build" {
  lifecycle {
    precondition {
      condition     = local.dist_ready
      error_message = "Run npm run build in the repo root before terraform apply."
    }
  }
}

resource "aws_s3_bucket" "site" {
  bucket        = "philoscroll-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "philoscroll"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "site" {
  for_each = local.site_files

  bucket = aws_s3_bucket.site.id
  key    = each.value
  source = "${local.dist_dir}/${each.value}"
  etag   = filemd5("${local.dist_dir}/${each.value}")
  content_type = lookup(
    local.content_types,
    lower(element(reverse(split(".", each.value)), 0)),
    "application/octet-stream",
  )
  cache_control = endswith(lower(each.value), ".html") ? "no-cache" : "public, max-age=31536000, immutable"

  depends_on = [
    terraform_data.site_build,
    aws_s3_bucket_public_access_block.site,
    aws_s3_bucket_server_side_encryption_configuration.site,
  ]
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "philoscroll"
  description                       = "Read the scroll bucket from CloudFront only."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "gate" {
  name    = "philoscroll-gate"
  runtime = "cloudfront-js-2.0"
  comment = "Admit the phone link, then remember the phone with a cookie."
  publish = true
  code = templatefile("${path.module}/auth.js.tftpl", {
    password_json    = jsonencode(var.access_password)
    query_name_json  = jsonencode(local.access_param)
    cookie_name_json = jsonencode(local.access_cookie)
  })
}

resource "aws_cloudfront_cache_policy" "site" {
  name        = "philoscroll-files"
  comment     = "Honor origin cache headers. The password is not part of the cache key."
  default_ttl = 0
  max_ttl     = 31536000
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = "PriceClass_All"
  comment             = "Philokalia scroll"
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "site"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "site"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = aws_cloudfront_cache_policy.site.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.gate.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "philoscroll"
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFront"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.site.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
        }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.site]
}
