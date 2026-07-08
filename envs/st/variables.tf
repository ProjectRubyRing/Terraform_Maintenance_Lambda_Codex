variable "env" {
  description = "Environment name."
  type        = string
  default     = "st"

  validation {
    condition     = can(regex("^[a-z0-9-]{1,12}$", var.env))
    error_message = "env must be 1-12 characters and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "aws_region" {
  description = "AWS region where resources are deployed."
  type        = string
  default     = "ap-northeast-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must look like ap-northeast-1."
  }
}

variable "system_name" {
  description = "System name used for resource names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,24}$", var.system_name))
    error_message = "system_name must be 1-24 characters and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "name_prefix" {
  description = "Optional resource name prefix."
  type        = string
  default     = null
}

variable "listener_arn" {
  description = "Existing ALB listener ARN."
  type        = string
}

variable "listener_rule_priority" {
  description = "ALB listener rule priority."
  type        = number
}

variable "host_header_values" {
  description = "ALB host header condition values."
  type        = list(string)
  default     = []
}

variable "path_pattern_values" {
  description = "ALB path pattern condition values."
  type        = list(string)
  default     = ["/*"]
}

variable "http_header_conditions" {
  description = "Optional ALB HTTP header conditions."
  type = list(object({
    name   = string
    values = list(string)
  }))
  default = []
}

variable "query_string_conditions" {
  description = "Optional ALB query string conditions."
  type = list(object({
    key   = optional(string)
    value = string
  }))
  default = []
}

variable "api_path_prefixes" {
  description = "Lambda API path prefixes."
  type        = list(string)
  default     = ["/api"]
}

variable "maintenance_title" {
  description = "Maintenance page title."
  type        = string
}

variable "maintenance_message" {
  description = "Maintenance page main message."
  type        = string
}

variable "maintenance_detail" {
  description = "Maintenance page detail text."
  type        = string
  default     = "Please try again later."
}

variable "status_code" {
  description = "HTTP status code returned by Lambda."
  type        = number
  default     = 503
}

variable "retry_after_seconds" {
  description = "Retry-After header value in seconds."
  type        = number
  default     = 300
}

variable "cors_enabled" {
  description = "Whether Lambda returns CORS headers."
  type        = bool
  default     = false
}

variable "cors_allow_origin" {
  description = "Access-Control-Allow-Origin value."
  type        = string
  default     = "*"
}

variable "inline_css" {
  description = "Whether Lambda embeds CSS into the HTML response."
  type        = bool
  default     = true
}

variable "css_path" {
  description = "Path that returns standalone maintenance CSS."
  type        = string
  default     = "/maintenance.css"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention days."
  type        = number
  default     = 30
}

variable "log_group_skip_destroy" {
  description = "Whether Terraform should skip log group deletion during destroy."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
