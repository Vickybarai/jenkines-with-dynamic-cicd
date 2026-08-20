locals {
  # EKS ships with default, kube-system, kube-public, and kube-node-lease.
  cluster_namespaces = toset(["default", "kube-system", "kube-public", "kube-node-lease"])

  create_ingress_namespace = var.create_ingress && !contains(local.cluster_namespaces, var.ingress_namespace)

  name_prefix = "${var.project_name}-${var.environment}"

  base_tags = merge(
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
      Module      = "alb-ingress"
    },
    var.additional_tags
  )

  alb_security_group_name_prefix = coalesce(
    var.alb_security_group_name_prefix,
    "${var.cluster_name}-alb-"
  )

  ingress_annotations = {
    "alb.ingress.kubernetes.io/scheme"                              = "internet-facing"
    "alb.ingress.kubernetes.io/target-type"                         = "ip"
    "alb.ingress.kubernetes.io/load-balancer-name"                  = var.load_balancer_name
    "alb.ingress.kubernetes.io/security-groups"                     = aws_security_group.alb.id
    "alb.ingress.kubernetes.io/manage-backend-security-group-rules" = "true"
    "alb.ingress.kubernetes.io/backend-protocol"                    = "HTTP"
    "alb.ingress.kubernetes.io/healthcheck-path"                    = var.healthcheck_path
    "alb.ingress.kubernetes.io/healthcheck-interval-seconds"        = "30"
    "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"         = "5"
    "alb.ingress.kubernetes.io/healthy-threshold-count"             = "2"
    "alb.ingress.kubernetes.io/unhealthy-threshold-count"           = "3"
    "alb.ingress.kubernetes.io/listen-ports"                        = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
    "alb.ingress.kubernetes.io/certificate-arn"                     = var.acm_certificate_arn
    "alb.ingress.kubernetes.io/ssl-redirect"                        = "443"
    "alb.ingress.kubernetes.io/ssl-policy"                          = var.ssl_policy
  }
}
