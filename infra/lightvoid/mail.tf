resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

resource "aws_ses_domain_mail_from" "main" {
  domain           = aws_ses_domain_identity.main.domain
  mail_from_domain = "bounce.${var.domain_name}"
}

resource "aws_route53_record" "mail_from_mx" {
  zone_id = local.zone_id
  name    = aws_ses_domain_mail_from.main.mail_from_domain
  type    = "MX"
  ttl     = 600
  records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

resource "aws_route53_record" "mail_from_spf" {
  zone_id = local.zone_id
  name    = aws_ses_domain_mail_from.main.mail_from_domain
  type    = "TXT"
  ttl     = 600
  records = ["v=spf1 include:amazonses.com ~all"]
}

resource "aws_route53_record" "ses_verification" {
  zone_id = local.zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.main.verification_token]
}

resource "aws_route53_record" "ses_dkim" {
  count = 3

  zone_id = local.zone_id
  name    = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.main.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "spf" {
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 600
  records = ["v=spf1 include:amazonses.com ~all"]
}

resource "aws_route53_record" "dmarc" {
  zone_id = local.zone_id
  name    = "_dmarc.${var.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = ["v=DMARC1; p=none; rua=mailto:${var.inbound_forward_to}"]
}

resource "aws_route53_record" "inbound_mx" {
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 600
  records = ["10 inbound-smtp.${var.aws_region}.amazonaws.com"]
}

resource "aws_ses_email_identity" "forward_target" {
  email = var.inbound_forward_to
}

resource "aws_s3_bucket" "inbound_mail" {
  bucket        = "lightvoid-inbound-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "lightvoid-inbound-mail"
  }
}

resource "aws_s3_bucket_public_access_block" "inbound_mail" {
  bucket                  = aws_s3_bucket.inbound_mail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "inbound_mail" {
  bucket = aws_s3_bucket.inbound_mail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "inbound_mail" {
  bucket = aws_s3_bucket.inbound_mail.id

  rule {
    id     = "expire-inbound"
    status = "Enabled"

    filter {
      prefix = "incoming/"
    }

    expiration {
      days = 14
    }
  }
}

resource "aws_ses_receipt_rule_set" "main" {
  rule_set_name = "lightvoid-inbound"
}

resource "aws_ses_active_receipt_rule_set" "main" {
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
}

data "archive_file" "mail_forward" {
  type        = "zip"
  source_file = "${path.module}/lambda/mail_forward.py"
  output_path = "${path.module}/lambda/mail_forward.zip"
}

resource "aws_iam_role" "mail_forward" {
  name = "lightvoid-mail-forward"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "mail_forward" {
  name = "lightvoid-mail-forward"
  role = aws_iam_role.mail_forward.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendRawEmail",
          "ses:SendEmail",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
        ]
        Resource = "${aws_s3_bucket.inbound_mail.arn}/*"
      },
    ]
  })
}

resource "aws_lambda_function" "mail_forward" {
  function_name = "lightvoid-mail-forward"
  role          = aws_iam_role.mail_forward.arn
  handler       = "mail_forward.handler"
  runtime       = "python3.12"
  timeout       = 30
  filename      = data.archive_file.mail_forward.output_path
  source_code_hash = data.archive_file.mail_forward.output_base64sha256

  environment {
    variables = {
      FORWARD_TO   = var.inbound_forward_to
      FORWARD_FROM = "${var.support_mailbox}@${var.domain_name}"
      MAIL_BUCKET  = aws_s3_bucket.inbound_mail.id
      MAIL_PREFIX  = "incoming/"
    }
  }
}

resource "aws_lambda_permission" "ses_invoke" {
  statement_id  = "AllowExecutionFromSES"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mail_forward.function_name
  principal     = "ses.amazonaws.com"
}

resource "aws_ses_receipt_rule" "inbound" {
  name          = "lightvoid-inbound"
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
  recipients    = [var.domain_name]
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name       = aws_s3_bucket.inbound_mail.id
    object_key_prefix = "incoming/"
    position          = 1
  }

  lambda_action {
    function_arn    = aws_lambda_function.mail_forward.arn
    invocation_type = "Event"
    position        = 2
  }

  depends_on = [
    aws_lambda_permission.ses_invoke,
    aws_s3_bucket_public_access_block.inbound_mail,
  ]
}

resource "aws_s3_bucket_policy" "inbound_mail" {
  bucket = aws_s3_bucket.inbound_mail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSESPuts"
      Effect    = "Allow"
      Principal = { Service = "ses.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.inbound_mail.arn}/incoming/*"
      Condition = {
        StringEquals = {
          "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}
