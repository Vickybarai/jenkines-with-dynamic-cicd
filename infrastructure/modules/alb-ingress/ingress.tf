resource "kubernetes_ingress_v1" "api" {
  count = var.create_ingress ? 1 : 0

  metadata {
    name        = var.ingress_name
    namespace   = var.ingress_namespace
    annotations = local.ingress_annotations
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = var.ingress_host

      dynamic "http" {
        for_each = [1]
        content {
          dynamic "path" {
            for_each = var.ingress_paths
            content {
              path      = path.value.path
              path_type = "Prefix"

              backend {
                service {
                  name = path.value.service_name
                  port {
                    number = path.value.service_port
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    kubernetes_namespace_v1.ingress,
  ]
}
