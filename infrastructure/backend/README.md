# Backend stack

Terraform root for backend infrastructure: **VPC** then **EKS**. Shared modules live in [`../modules/`](../modules/).

## Layout

```text
backend/
├── Jenkinsfile
├── backend.tf              # S3 remote state (partial config)
├── backend.hcl.example       # Copy to backend.hcl (gitignored)
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
| State key | `backend/terraform.tfstate` |
| Example bucket | `cdec-alpha-terraform-state` |

```bash
cd infrastructure/backend
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform plan
```

## Module wiring

```text
module "vpc"  →  ../modules/vpc
module "eks"  →  ../modules/eks   (uses vpc outputs)
```

## Jenkins

**Script path:** `infrastructure/backend/Jenkinsfile`

1. AWS credential: `aws-backend-terraform`
2. On the agent, add `terraform.tfvars` and `backend.hcl` (from the `.example` files)

## kubectl access

EKS uses **IAM access entries**. Without an access entry for the **exact** IAM principal kubectl uses, you get *the server has asked for the client to provide credentials* even after `aws eks update-kubeconfig`.

### Common mistake: wrong ARN on EC2

On an EC2 instance, `aws sts get-caller-identity` returns a **session** ARN:

```text
arn:aws:sts::439055361064:assumed-role/MyEc2Role/i-0abc123...
```

EKS access entries require the **IAM role** ARN:

```text
arn:aws:iam::439055361064:role/MyEc2Role
```

Terraform apply with `include_caller_as_cluster_admin = true` only grants the **Jenkins/Terraform IAM user** — not the EC2 instance role you use when SSH'd in as root.

### Fix (on the EC2 host where kubectl fails)

```bash
# 1. Who is kubectl authenticating as?
aws sts get-caller-identity

# 2. EC2 instance profile role ARN (pick one method)

# From assumed-role ARN (always works):
ASSUMED=$(aws sts get-caller-identity --query Arn --output text)
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
ROLE=$(echo "$ASSUMED" | cut -d/ -f2)
echo "arn:aws:iam::${ACCOUNT}:role/${ROLE}"

# Or IMDSv2 (required if IMDSv1 is disabled):
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
ROLE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/)
echo "arn:aws:iam::${ACCOUNT}:role/${ROLE}"

# 3. Is that role in the cluster access list?
aws eks list-access-entries --cluster-name cdec-eks-dev --region eu-west-1

# 4. Can this identity get a token?
aws eks get-token --cluster-name cdec-eks-dev --region eu-west-1
```

### Terraform (durable fix)

Add the EC2 role **name** to `terraform.tfvars`:

```hcl
cluster_admin_iam_role_names = ["MyEc2Role"]
```

Or the full IAM role ARN in `cluster_admin_principal_arns`. Then `terraform apply`.

### Immediate unblock (no Terraform)

```bash
ROLE=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
ROLE_ARN="arn:aws:iam::${ACCOUNT}:role/${ROLE}"

aws eks create-access-entry --cluster-name cdec-eks-dev --principal-arn "$ROLE_ARN" --region eu-west-1
aws eks associate-access-policy --cluster-name cdec-eks-dev --principal-arn "$ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster --region eu-west-1

kubectl get pods
```

The principal also needs `eks:DescribeCluster` (for `update-kubeconfig`).

## Application pairing

API / services source: [`application/backend/`](../../application/backend/README.md).
