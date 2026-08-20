# access-entries.tf — IAM principals allowed to call the Kubernetes API (replaces aws-auth for API mode)

data "aws_caller_identity" "current" {}

# Resolve role names to canonical ARNs (includes path). Fails at plan if the role does not exist.
data "aws_iam_role" "cluster_admin" {
  for_each = toset(var.cluster_admin_iam_role_names)
  name     = each.key
}

locals {
  # EC2/Jenkins hosts use assumed-role sessions at runtime; EKS access entries require iam::role ARNs.
  cluster_admin_role_arns = [
    for name in var.cluster_admin_iam_role_names :
    data.aws_iam_role.cluster_admin[name].arn
  ]

  # Static map keys are required: for_each cannot use a set when values include apply-time ARNs.
  cluster_admin_entries = merge(
    { for idx, arn in var.cluster_admin_principal_arns : "principal-${idx}" => arn },
    { for idx, arn in local.cluster_admin_role_arns : "role-${idx}" => arn },
    var.include_caller_as_cluster_admin ? { "terraform-caller" = data.aws_caller_identity.current.arn } : {},
  )

  cluster_admin_principal_arns = values(local.cluster_admin_entries)
}

resource "aws_eks_access_entry" "cluster_admin" {
  for_each = local.cluster_admin_entries

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = merge(
    local.base_tags,
    {
      Name = "${var.cluster_name}-admin-access"
    },
  )

  depends_on = [aws_eks_cluster.this]
}

resource "aws_eks_access_policy_association" "cluster_admin" {
  for_each = local.cluster_admin_entries

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.cluster_admin]
}
