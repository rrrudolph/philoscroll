# lightvoid.app on AWS

Publisher domain: `@lightvoid.app` mail, HTTPS on subdomains, starter PhiloScroll privacy page.

## Domain

Register `lightvoid.app` in **Route 53 → Registered domains** (or CLI `register-domain`) in this AWS account. That creates the hosted zone Terraform expects.

## Apply

```powershell
terraform -chdir=infra/lightvoid init
terraform -chdir=infra/lightvoid apply
```

Set `inbound_forward_to` in `terraform.tfvars` (see example).

## What you get

| Piece | Purpose |
|--------|---------|
| Route 53 records | ACM validation, CloudFront aliases, SES (MX/SPF/DKIM/DMARC) |
| ACM + CloudFront + S3 | `https://philoscroll.lightvoid.app/` and `/privacy.html` |
| SES + Lambda | Inbound `@lightvoid.app` → your inbox |

**Store listing**

- Support email: `support@lightvoid.app` (any `@lightvoid.app` address forwards to `inbound_forward_to`; `terraform output support_email` for the canonical address)
- PhiloScroll privacy: output `philoscroll_privacy_url`

**New app:** add HTML under `site/`, wire S3 objects in `web.tf`, use `https://<app>.lightvoid.app/`.

## SES sandbox

Request **production access** in SES when you need to reply to arbitrary addresses from `@lightvoid.app`. Inbound forwarding to `inbound_forward_to` works after you click the SES verification email for that address.

**Gmail spam folder:** New domains often land in Spam until you mark one forward as *Not spam*. Optional: filter `from:lightvoid.app` → Never send to Spam.
