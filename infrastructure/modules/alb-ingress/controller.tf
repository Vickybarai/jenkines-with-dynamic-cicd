resource "kubernetes_namespace_v1" "ingress" {
  count = local.create_ingress_namespace ? 1 : 0

  metadata {
    name = var.ingress_namespace
  }
}

resource "kubernetes_service_account_v1" "load_balancer_controller" {
  count = var.install_controller ? 1 : 0

  metadata {
    name      = var.controller_service_account_name
    namespace = var.controller_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.load_balancer_controller.arn
    }
    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  count = var.install_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.controller_chart_version
  namespace  = var.controller_namespace

  wait    = true
  timeout = 600

  set = [
    {
      name  = "clusterName"
      value = var.cluster_name
    },
    {
      name  = "region"
      value = var.aws_region
    },
    {
      name  = "vpcId"
      value = var.vpc_id
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = var.controller_service_account_name
    },
    {
      name  = "crds.create"
      value = "true"
    },
  ]

  depends_on = [
    aws_iam_role_policy_attachment.load_balancer_controller,
    kubernetes_service_account_v1.load_balancer_controller,
  ]
}
