variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for queue naming"
  type        = string
}

variable "max_receive_count_before_dlq" {
  description = "Maximum number of receives before message goes to DLQ"
  type        = number
  default     = 3

  validation {
    condition     = var.max_receive_count_before_dlq > 0 && var.max_receive_count_before_dlq <= 1000
    error_message = "max_receive_count_before_dlq must be between 1 and 1000"
  }
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

