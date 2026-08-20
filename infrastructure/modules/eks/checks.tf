# Cross-variable constraints (Terraform 1.9+ allows only self-references in variable validation).

check "node_group_scaling" {
  assert {
    condition     = var.min_size <= var.desired_size && var.desired_size <= var.max_size
    error_message = "desired_size must be between min_size and max_size (inclusive)."
  }

  assert {
    condition     = var.max_size >= var.min_size
    error_message = "max_size must be >= min_size."
  }
}
