# iam.tf — IAM roles for the EKS control plane and managed worker nodes
#
# AWS manages the control plane; these roles let AWS and your nodes call required APIs.

# -----------------------------------------------------------------------------
# Cluster IAM role — assumed by the EKS service to manage the control plane
# -----------------------------------------------------------------------------

resource "aws_iam_role" "cluster" {
  name = "${local.name_prefix}-${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.base_tags, { Name = "${var.cluster_name}-cluster-role" })
}

resource "aws_iam_role_policy_attachment" "cluster_amazon_eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# -----------------------------------------------------------------------------
# Node IAM role — assumed by EC2 instances in the managed node group
# -----------------------------------------------------------------------------

resource "aws_iam_role" "node" {
  name = "${local.name_prefix}-${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.base_tags, { Name = "${var.cluster_name}-node-role" })
}

# Worker node: register with cluster and run pods
resource "aws_iam_role_policy_attachment" "node_amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

# VPC CNI plugin — assigns pod IPs in your VPC
resource "aws_iam_role_policy_attachment" "node_amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

# Pull images from Amazon ECR
resource "aws_iam_role_policy_attachment" "node_amazon_ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# -----------------------------------------------------------------------------
# IRSA example (commented pattern — create per workload in separate IAM resources)
# -----------------------------------------------------------------------------
#
# resource "aws_iam_role" "app_sa" {
#   name = "${var.cluster_name}-my-app-sa"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = {
#         Federated = aws_iam_openid_connect_provider.cluster.arn
#       }
#       Action = "sts:AssumeRoleWithWebIdentity"
#       Condition = {
#         StringEquals = {
#           "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:NAMESPACE:SA_NAME"
#           "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
#         }
#       }
#     }]
#   })
# }
