# security-groups.tf — Supplemental security group for worker nodes
#
# EKS also creates a cluster security group automatically. We attach both to nodes
# so the control plane and workers can communicate safely.

resource "aws_security_group" "node" {
  name_prefix = "${var.cluster_name}-node-"
  description = "Additional security group for EKS managed worker nodes"
  vpc_id      = var.vpc_id

  tags = merge(
    local.base_tags,
    {
      Name = "${var.cluster_name}-node-sg"
      # Do not tag with kubernetes.io/cluster/<name> — EKS already tags the cluster
      # primary SG. Two cluster-tagged SGs on the same node ENI breaks the AWS Load
      # Balancer Controller (target-type: ip) target group reconciliation.
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Allow all traffic from the EKS-managed cluster security group (control plane ↔ nodes)
resource "aws_security_group_rule" "node_ingress_from_cluster" {
  description              = "Allow worker nodes to receive traffic from the EKS cluster security group"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

# Node-to-node traffic (pod networking, kubelet, etc.)
resource "aws_security_group_rule" "node_ingress_self" {
  description       = "Allow nodes in this group to communicate with each other"
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  self              = true
}

# Outbound internet via NAT (pull images, APIs) — restrict in high-compliance environments
resource "aws_security_group_rule" "node_egress_all" {
  description       = "Allow outbound traffic (typically via NAT Gateway in private subnets)"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node.id
}

# Allow cluster SG to reach nodes on port 443 (kubelet/API paths used by control plane)
resource "aws_security_group_rule" "cluster_ingress_from_node" {
  description              = "Allow cluster to communicate with worker nodes"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.node.id
}
