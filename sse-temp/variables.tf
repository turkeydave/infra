variable "project_id" {
  type        = string
  description = "Personal GCP project ID."
}

variable "region" {
  type        = string
  description = "Region for Cloud Run and Redis."
  default     = "us-central1"
}

variable "network_name" {
  type        = string
  description = "PoC VPC network name."
  default     = "temp-sse-poc"
}

variable "subnet_name" {
  type        = string
  description = "PoC subnet name."
  default     = "temp-sse-poc-us-central1"
}

variable "subnet_cidr" {
  type        = string
  description = "Primary subnet CIDR for Direct VPC egress."
  default     = "10.20.0.0/24"
}

variable "private_services_cidr" {
  type        = string
  description = "Reserved CIDR for private services access."
  default     = "10.30.0.0/20"
}

variable "artifact_registry_repository_id" {
  type        = string
  description = "Artifact Registry repository for PoC images."
  default     = "temp-sse-poc"
}

variable "backend_service_name" {
  type        = string
  description = "Backend Cloud Run service name."
  default     = "temp-sse-backend"
}

variable "gateway_service_name" {
  type        = string
  description = "Gateway Cloud Run service name."
  default     = "temp-sse-gateway"
}

variable "client_service_name" {
  type        = string
  description = "Static client Cloud Run service name."
  default     = "temp-sse-client"
}

variable "backend_image" {
  type        = string
  description = "Backend container image URL."
}

variable "gateway_image" {
  type        = string
  description = "Gateway container image URL."
}

variable "client_image" {
  type        = string
  description = "Client container image URL."
}

variable "redis_tier" {
  type        = string
  description = "Memorystore tier."
  default     = "BASIC"
}

variable "redis_memory_size_gb" {
  type        = number
  description = "Redis size in GiB."
  default     = 1
}

variable "jwt_secret_name" {
  type        = string
  description = "Secret Manager name for the shared SSE JWT secret."
  default     = "TEMP_SSE_POC_JWT_SECRET"
}

variable "app_jwt_secret_name" {
  type        = string
  description = "Secret Manager name for the demo app JWT secret."
  default     = "TEMP_SSE_POC_APP_JWT_SECRET"
}

variable "app_jwt_secret_value" {
  type        = string
  description = "Shared demo app JWT secret used by the browser client and backend."
  sensitive   = true
}

variable "allowed_origins" {
  type        = list(string)
  description = "Allowed browser origins for the gateway."
  default     = []
}
