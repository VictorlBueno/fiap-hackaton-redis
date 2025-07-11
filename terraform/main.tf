data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "fiap-hack-terraform-state"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "redis"
  }
  
  # Verificar se o cluster está pronto
  cluster_ready = data.terraform_remote_state.eks.outputs.cluster_endpoint != null
}

# Namespace
resource "kubernetes_namespace" "redis" {
  metadata {
    name = var.redis_namespace
    labels = local.tags
  }
  
  depends_on = [data.terraform_remote_state.eks]
}

# Secret
resource "kubernetes_secret" "redis" {
  metadata {
    name      = "${var.redis_name}-secret"
    namespace = kubernetes_namespace.redis.metadata[0].name
  }

  type = "Opaque"

  data = {
    redis-password = var.redis_password
  }
}

# Persistent Volume Claim
resource "kubernetes_persistent_volume_claim" "redis" {
  metadata {
    name      = "${var.redis_name}-pvc"
    namespace = kubernetes_namespace.redis.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "fiap-hack-gp2"
    resources {
      requests = {
        storage = var.redis_storage_size
      }
    }
  }
  
  timeouts {
    create = "2m"
  }
  
  depends_on = [data.terraform_remote_state.eks]
}

# Deployment
resource "kubernetes_deployment" "redis" {
  metadata {
    name      = var.redis_name
    namespace = kubernetes_namespace.redis.metadata[0].name
    labels = local.tags
  }

  spec {
    replicas = var.redis_replicas

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        app = var.redis_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.redis_name
        }
      }

      spec {
        container {
          name  = var.redis_name
          image = var.redis_image

          port {
            container_port = 6379
            name          = "redis"
          }

          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.redis.metadata[0].name
                key  = "redis-password"
              }
            }
          }

          args = [
            "--requirepass",
            "$(REDIS_PASSWORD)",
            "--appendonly",
            "yes",
            "--maxmemory",
            var.redis_max_memory,
            "--maxmemory-policy",
            "allkeys-lru"
          ]

          resources {
            requests = {
              cpu    = var.redis_cpu_request
              memory = var.redis_memory_request
            }
            limits = {
              cpu    = var.redis_cpu_limit
              memory = var.redis_memory_limit
            }
          }

          liveness_probe {
            tcp_socket {
              port = 6379
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            tcp_socket {
              port = 6379
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          volume_mount {
            name       = "redis-data"
            mount_path = "/data"
          }
        }

        volume {
          name = "redis-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.redis.metadata[0].name
          }
        }
      }
    }
  }

  timeouts {
    create = "15m"
    update = "10m"
    delete = "10m"
  }
  
  depends_on = [kubernetes_persistent_volume_claim.redis]
}

# Service
resource "kubernetes_service" "redis" {
  metadata {
    name      = "${var.redis_name}-service"
    namespace = kubernetes_namespace.redis.metadata[0].name
    labels = local.tags
  }

  spec {
    type = "ClusterIP"

    port {
      port        = 6379
      target_port = 6379
      protocol    = "TCP"
      name        = "redis"
    }

    selector = {
      app = var.redis_name
    }
  }
}

# Outputs
output "redis_host" {
  description = "Host do Redis"
  value       = "${kubernetes_service.redis.metadata[0].name}.${kubernetes_namespace.redis.metadata[0].name}.svc.cluster.local"
}

output "redis_port" {
  description = "Porta do Redis"
  value       = 6379
}

output "redis_password" {
  description = "Senha do Redis"
  value       = var.redis_password
  sensitive   = true
}

output "redis_connection_string" {
  description = "String de conexão do Redis"
  value       = "redis://:${var.redis_password}@${kubernetes_service.redis.metadata[0].name}.${kubernetes_namespace.redis.metadata[0].name}.svc.cluster.local:6379"
  sensitive   = true
}

output "redis_namespace" {
  description = "Namespace do Redis"
  value       = kubernetes_namespace.redis.metadata[0].name
} 