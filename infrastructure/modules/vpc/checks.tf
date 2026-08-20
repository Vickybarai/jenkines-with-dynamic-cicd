# Cross-variable constraints (Terraform 1.9+ allows only self-references in variable validation).

check "subnet_az_alignment" {
  assert {
    condition = (
      length(var.availability_zones) == length(var.public_subnet_cidrs) &&
      length(var.availability_zones) == length(var.private_subnet_cidrs)
    )
    error_message = "availability_zones, public_subnet_cidrs, and private_subnet_cidrs must have the same length."
  }
}
