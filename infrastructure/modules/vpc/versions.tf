# versions.tf — Terraform and provider version constraints
#
# Pinning versions prevents surprise breaking changes when someone runs
# `terraform init` on a new machine or in CI.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0, < 7.0.0"
    }
  }
}
