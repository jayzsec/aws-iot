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
variable "timestream_memory_store_retention_hours" {
  type        = number
  default     = 24
  description = "Duration in hours to keep telemetry in Timestream in-memory store"
}

variable "timestream_magnetic_store_retention_days" {
  type        = number
  default     = 365
  description = "Duration in days to keep telemetry in Timestream magnetic disk store"
}
