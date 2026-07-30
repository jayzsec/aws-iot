# global variable
variable "project_name" {
  type        = string
  default     = "iot-fleet-platform"
  description = "Base name for resources"
}

variable "aws_region" {
  type        = string
  default     = "ap-southeast-2"
  description = "Default region for the project"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment - dev, staging, prod"
}

#####################################################
# Timestream vars
#####################################################
variable "domain_name" {
  type        = string
  default     = "cabang.dev"
  description = "Domain hosted in cloudflare"
}

variable "subdomain" {
  type        = string
  default     = "iot.cabang.dev"
  description = "Custom subdomain for IoT Fleet Platform"
}
