# node-group.tf — EKS Managed Node Group with autoscaling and rolling updates
#
# Managed node groups let AWS handle AMI updates, draining, and scaling configuration.

locals {
  node_group_name = "${var.cluster_name}-workers"

  # Optional tags for Kubernetes Cluster Autoscaler (scales beyond managed min/max when installed)
  autoscaler_tags = var.enable_cluster_autoscaler_tags ? {
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  } : {}
}

# Launch template attaches cluster + node security groups and sets root volume size
resource "aws_launch_template" "node" {
  name_prefix = "${local.node_group_name}-"

  vpc_security_group_ids = [
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
    aws_security_group.node.id,
  ]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.disk_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.base_tags,
      {
        Name = local.node_group_name
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      local.base_tags,
      {
        Name = "${local.node_group_name}-volume"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = local.node_group_name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  # Rolling update — only a percentage of nodes unavailable at once
  update_config {
    max_unavailable_percentage = var.node_max_unavailable_percentage
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  labels = {
    environment = var.environment
    project     = var.project_name
  }

  tags = merge(
    local.base_tags,
    local.autoscaler_tags,
    {
      Name = local.node_group_name
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.node_amazon_eks_cni_policy,
    aws_iam_role_policy_attachment.node_amazon_ecr_read_only,
  ]
}
