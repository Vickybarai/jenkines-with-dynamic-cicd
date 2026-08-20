# Frontend stack

Terraform root for the frontend (**S3 + CloudFront + Route 53**). Calls shared modules in [`../modules/`](../modules/).

## Layout

```text
frontend/
├── Jenkinsfile
├── backend.tf              # S3 remote state (partial config)
├── backend.hcl.example     # Copy to backend.hcl (gitignored)
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
└── terraform.tfvars.example
```

## Remote state

State is stored in **S3** with **DynamoDB** locking. See [`../REMOTE_STATE.md`](../REMOTE_STATE.md).

| Setting | Value |
|---------|--------|
| State key | `frontend/terraform.tfstate` |
| Example bucket | `cdec-alpha-terraform-state` |

```bash
cd infrastructure/frontend
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform plan
```

## Module sources

```hcl
module "cloudfront" { source = "../modules/cloudfront" }  # S3 + CloudFront
module "route53"   { source = "../modules/route53" }
```

## DNS

Set `dns_zone_name` in `terraform.tfvars` to a **domain you own** (not `example.com` — AWS reserves it). After apply, delegate your domain at the registrar using the `route53_name_servers` output.

To use an existing zone instead, set `route53_zone_id` and keep `dns_zone_name` for reference.

## Deploy the application

After `terraform apply`:

```bash
cd application/frontend
npm ci && npm run build

BUCKET=$(terraform -chdir=../../infrastructure/frontend output -raw s3_bucket_name)
DIST_ID=$(terraform -chdir=../../infrastructure/frontend output -raw cloudfront_distribution_id)

aws s3 sync dist/ "s3://${BUCKET}/" --delete
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*"
```

## Jenkins

**Script path:** `infrastructure/frontend/Jenkinsfile`

1. AWS credential: `aws-frontend-terraform`
2. On the agent, add `terraform.tfvars` and `backend.hcl` (from the `.example` files)

## Application pairing

UI source: [`application/frontend/`](../../application/frontend/README.md).
