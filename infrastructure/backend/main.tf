# Backend stack — VPC first, then EKS (uses VPC outputs)

check "alb_ingress_inputs" {
  assert {
    condition     = !var.enable_alb_ingress || (var.ingress_host != "" && var.acm_certificate_arn != "")
    error_message = "ingress_host and acm_certificate_arn are required when enable_alb_ingress is true."
  }
}

module "vpc" {
  source = "../modules/vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones

  cluster_name = var.cluster_name
  environment  = var.environment
  project_name = var.project_name

  single_nat_gateway = var.single_nat_gateway
  additional_tags    = var.additional_tags
}

module "eks" {
  source = "../modules/eks"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  node_instance_types = var.node_instance_types
  desired_size        = var.desired_size
  min_size            = var.min_size
  max_size            = var.max_size
  disk_size           = var.disk_size

  environment  = var.environment
  project_name = var.project_name

  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  enable_cluster_autoscaler_tags = var.enable_cluster_autoscaler_tags
  additional_tags                = var.additional_tags

  cluster_admin_principal_arns    = var.cluster_admin_principal_arns
  cluster_admin_iam_role_names    = var.cluster_admin_iam_role_names
  include_caller_as_cluster_admin = var.include_caller_as_cluster_admin

  depends_on = [module.vpc]
}

module "alb_ingress" {
  source = "../modules/alb-ingress"
  count  = var.enable_alb_ingress ? 1 : 0

  cluster_name      = module.eks.cluster_name
  vpc_id            = module.vpc.vpc_id
  aws_region        = var.aws_region
  environment       = var.environment
  project_name      = var.project_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  ingress_host          = var.ingress_host
  acm_certificate_arn   = var.acm_certificate_arn
  load_balancer_name    = var.alb_name
  allowed_inbound_cidrs = var.alb_allowed_inbound_cidrs
  ingress_paths         = var.ingress_paths

  additional_tags = var.additional_tags

  depends_on = [module.eks]
}
