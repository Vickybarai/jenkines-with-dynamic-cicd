# versions.tf — Provider pins for the EKS module

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0, < 7.0.0"
    }
    # Used to fetch the TLS thumbprint for the EKS OIDC provider (IRSA)
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}
