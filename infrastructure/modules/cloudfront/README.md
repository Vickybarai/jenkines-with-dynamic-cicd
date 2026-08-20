# CloudFront module

Creates an **S3 + CloudFront** static frontend stack for the Vite/React SPA in [`application/frontend/`](../../../application/frontend/).

## What this module creates

- Private **S3 bucket** (AES256 encryption, public access blocked)
- **Origin Access Control** (OAC) so only CloudFront can read the bucket
- **S3 bucket policy** scoped to the CloudFront distribution ARN
- **CloudFront distribution** with CachingOptimized policy and HTTPS redirect
- **SPA routing**: 403/404 responses return `index.html` with HTTP 200 (React Router)

## Deploy workflow

1. `terraform apply` in [`infrastructure/frontend/`](../../frontend/)
2. Build the app: `cd application/frontend && npm run build`
3. Sync `dist/` to the bucket:

```bash
aws s3 sync application/frontend/dist/ s3://<bucket_name>/ --delete
aws cloudfront create-invalidation \
  --distribution-id <distribution_id> \
  --paths "/*"
```

Use the `s3_bucket_name` and `cloudfront_distribution_id` outputs from the frontend stack.

## Usage

```hcl
module "cloudfront" {
  source = "../modules/cloudfront"

  application = "cdec-frontend"
  environment = "dev"

  aliases             = ["www.example.com"]
  acm_certificate_arn = var.acm_certificate_arn

  tags = {
    Component = "cloudfront"
  }
}
```

## Inputs

See [variables.tf](variables.tf). Required: `application`, `environment`.

## Outputs

| Output | Use |
|--------|-----|
| `bucket_id` | `aws s3 sync` target |
| `distribution_id` | Cache invalidation after deploy |
| `domain_name` | Alias target for Route 53 |
| `hosted_zone_id` | Alias zone ID for Route 53 |

## Notes

- ACM certificates for CloudFront custom domains must be in **us-east-1**.
- Pair with the [Route53 module](../route53/README.md) using `domain_name` and `hosted_zone_id` outputs.
