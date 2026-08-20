check "controller_required_for_ingress" {
  assert {
    condition     = !var.create_ingress || var.install_controller
    error_message = "install_controller must be true when create_ingress is true."
  }
}
