variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "fiap-hack"
}

variable "environment" {
  description = "Ambiente (development, staging, production)"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "redis_name" {
  description = "Nome do Redis"
  type        = string
  default     = "redis"
}

variable "redis_namespace" {
  description = "Namespace do Redis"
  type        = string
  default     = "redis"
}

variable "redis_image" {
  description = "Imagem Docker do Redis"
  type        = string
  default     = "redis:7-alpine"
}

variable "redis_password" {
  description = "Senha do Redis"
  type        = string
  sensitive   = true
}

variable "redis_replicas" {
  description = "Número de réplicas do Redis"
  type        = number
  default     = 1
}

variable "redis_storage_size" {
  description = "Tamanho do storage para Redis"
  type        = string
  default     = "1Gi"
}

variable "redis_max_memory" {
  description = "Memória máxima do Redis"
  type        = string
  default     = "128mb"
}

variable "redis_cpu_request" {
  description = "CPU request para Redis"
  type        = string
  default     = "50m"
}

variable "redis_cpu_limit" {
  description = "CPU limit para Redis"
  type        = string
  default     = "100m"
}

variable "redis_memory_request" {
  description = "Memória request para Redis"
  type        = string
  default     = "64Mi"
}

variable "redis_memory_limit" {
  description = "Memória limit para Redis"
  type        = string
  default     = "128Mi"
} 