variable "env" {
  description = "Environment name used for naming and tagging, for example j1, j2, j3, st, or pr."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,12}$", var.env))
    error_message = "env must be 1-12 characters and contain only lowercase letters, numbers, and hyphens."
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
  description = "Optional prefix prepended to resource names. Use this to avoid name collisions across accounts."
  type        = string
  default     = null

  validation {
    condition     = var.name_prefix == null || can(regex("^[a-z0-9-]{1,16}$", var.name_prefix))
    error_message = "name_prefix must be null or 1-16 characters containing only lowercase letters, numbers, and hyphens."
  }
}

variable "lambda_function_name" {
  description = "Optional explicit Lambda function name. When null, the module generates one from name_prefix, system_name, and env."
  type        = string
  default     = null

  validation {
    condition     = var.lambda_function_name == null || can(regex("^[a-zA-Z0-9-_]{1,64}$", var.lambda_function_name))
    error_message = "lambda_function_name must be null or a valid Lambda function name up to 64 characters."
  }
}

variable "target_group_name" {
  description = "Optional explicit ALB Lambda target group name. When null, the module generates one."
  type        = string
  default     = null

  validation {
    condition     = var.target_group_name == null || can(regex("^[a-zA-Z0-9-]{1,32}$", var.target_group_name))
    error_message = "target_group_name must be null or a valid ALB target group name up to 32 characters."
  }
}

variable "listener_arn" {
  description = "ARN of the existing ALB listener where the maintenance forwarding rule is created."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:elasticloadbalancing:[^:]+:[0-9]{12}:listener/app/.+", var.listener_arn))
    error_message = "listener_arn must be an ALB listener ARN."
  }
}

variable "listener_rule_priority" {
  description = "Priority for the ALB listener rule. It must be unique within the listener."
  type        = number

  validation {
    condition     = var.listener_rule_priority >= 1 && var.listener_rule_priority <= 50000
    error_message = "listener_rule_priority must be between 1 and 50000."
  }
}

variable "host_header_values" {
  description = "Optional host header values for the ALB listener rule condition, for example app.example.com."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for value in var.host_header_values : length(trimspace(value)) > 0])
    error_message = "host_header_values must not contain empty strings."
  }
}

variable "path_pattern_values" {
  description = "Optional path pattern values for the ALB listener rule condition, for example /app/*."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for value in var.path_pattern_values : startswith(value, "/")])
    error_message = "Every path pattern must start with /."
  }
}

variable "http_header_conditions" {
  description = "Optional HTTP header conditions for the ALB listener rule."
  type = list(object({
    name   = string
    values = list(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for condition in var.http_header_conditions :
      can(regex("^[A-Za-z0-9!#$%&'*+.^_`|~-]+$", condition.name)) && length(condition.values) > 0
    ])
    error_message = "Each HTTP header condition requires a valid header name and at least one value."
  }
}

variable "query_string_conditions" {
  description = "Optional query string conditions for the ALB listener rule."
  type = list(object({
    key   = optional(string)
    value = string
  }))
  default = []

  validation {
    condition     = alltrue([for condition in var.query_string_conditions : length(trimspace(condition.value)) > 0])
    error_message = "Each query string condition requires a non-empty value."
  }
}

variable "lambda_runtime" {
  description = "Lambda runtime. This module is designed for Python 3.13."
  type        = string
  default     = "python3.13"

  validation {
    condition     = var.lambda_runtime == "python3.13"
    error_message = "lambda_runtime must be python3.13 for this module."
  }
}

variable "lambda_architectures" {
  description = "Instruction set architectures for the Lambda function."
  type        = list(string)
  default     = ["x86_64"]

  validation {
    condition     = length(var.lambda_architectures) == 1 && contains(["x86_64", "arm64"], var.lambda_architectures[0])
    error_message = "lambda_architectures must contain exactly one value: x86_64 or arm64."
  }
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB."
  type        = number
  default     = 128

  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "lambda_memory_size must be between 128 and 10240."
  }
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 5

  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 30
    error_message = "lambda_timeout must be between 1 and 30 seconds for ALB usage."
  }
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrency for the Lambda function. Use -1 for unreserved concurrency."
  type        = number
  default     = -1

  validation {
    condition     = var.reserved_concurrent_executions >= -1
    error_message = "reserved_concurrent_executions must be -1 or greater."
  }
}

variable "publish" {
  description = "Whether to publish a new Lambda version on update."
  type        = bool
  default     = false
}

variable "permissions_boundary" {
  description = "Optional IAM permissions boundary ARN for the Lambda execution role."
  type        = string
  default     = null

  validation {
    condition     = var.permissions_boundary == null || can(regex("^arn:[^:]+:iam::[0-9]{12}:policy/.+", var.permissions_boundary))
    error_message = "permissions_boundary must be null or an IAM policy ARN."
  }
}

variable "lambda_role_name" {
  description = "Optional explicit IAM role name for the Lambda execution role."
  type        = string
  default     = null

  validation {
    condition     = var.lambda_role_name == null || can(regex("^[\\w+=,.@-]{1,64}$", var.lambda_role_name))
    error_message = "lambda_role_name must be null or a valid IAM role name up to 64 characters."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 3653], var.log_retention_days)
    error_message = "log_retention_days must be one of the CloudWatch Logs supported retention values."
  }
}

variable "log_group_skip_destroy" {
  description = "When true, Terraform removes the log group from state instead of deleting it during destroy. Useful for production retention safety."
  type        = bool
  default     = false
}

variable "maintenance_title" {
  description = "Title rendered into the maintenance HTML page."
  type        = string
  default     = "Service Maintenance"

  validation {
    condition     = length(var.maintenance_title) > 0
    error_message = "maintenance_title must not be empty."
  }
}

variable "maintenance_message" {
  description = "Main message rendered into the maintenance HTML page."
  type        = string
  default     = "Service is temporarily unavailable due to maintenance."

  validation {
    condition     = length(var.maintenance_message) > 0
    error_message = "maintenance_message must not be empty."
  }
}

variable "maintenance_detail" {
  description = "Additional detail rendered into the maintenance HTML page."
  type        = string
  default     = "Please try again later."
}

variable "status_code" {
  description = "HTTP status code returned by the Lambda function."
  type        = number
  default     = 503

  validation {
    condition     = var.status_code >= 200 && var.status_code <= 599
    error_message = "status_code must be between 200 and 599."
  }
}

variable "retry_after_seconds" {
  description = "Retry-After header value in seconds. Use 0 to omit the header."
  type        = number
  default     = 300

  validation {
    condition     = var.retry_after_seconds >= 0
    error_message = "retry_after_seconds must be 0 or greater."
  }
}

variable "cache_control" {
  description = "Cache-Control header value returned by the Lambda function."
  type        = string
  default     = "no-store, no-cache, must-revalidate, max-age=0"

  validation {
    condition     = length(trimspace(var.cache_control)) > 0
    error_message = "cache_control must not be empty."
  }
}

variable "inline_css" {
  description = "When true, maintenance.css is embedded into the HTML response. When false, HTML references css_path and CSS is served separately."
  type        = bool
  default     = true
}

variable "css_path" {
  description = "Request path that returns maintenance.css as a standalone CSS response."
  type        = string
  default     = "/maintenance.css"

  validation {
    condition     = startswith(var.css_path, "/") && endswith(var.css_path, ".css")
    error_message = "css_path must start with / and end with .css."
  }
}

variable "api_path_prefixes" {
  description = "Path prefixes treated as API requests by Lambda."
  type        = list(string)
  default     = ["/api"]

  validation {
    condition     = length(var.api_path_prefixes) > 0 && alltrue([for prefix in var.api_path_prefixes : startswith(prefix, "/")])
    error_message = "api_path_prefixes must contain at least one path prefix and every prefix must start with /."
  }
}

variable "api_detect_accept_json" {
  description = "When true, requests with Accept including application/json are treated as API requests."
  type        = bool
  default     = true
}

variable "api_detect_content_type_json" {
  description = "When true, requests with Content-Type including application/json are treated as API requests."
  type        = bool
  default     = true
}

variable "api_detect_x_requested_with" {
  description = "When true, requests with X-Requested-With: XMLHttpRequest are treated as API requests."
  type        = bool
  default     = true
}

variable "api_error_code" {
  description = "Machine-readable error code returned in API JSON responses."
  type        = string
  default     = "service_unavailable"

  validation {
    condition     = can(regex("^[a-z0-9_:-]+$", var.api_error_code))
    error_message = "api_error_code must contain lowercase letters, numbers, underscore, colon, or hyphen."
  }
}

variable "api_error_message" {
  description = "Human-readable error message returned in API JSON responses."
  type        = string
  default     = "Service is temporarily unavailable due to maintenance."

  validation {
    condition     = length(trimspace(var.api_error_message)) > 0
    error_message = "api_error_message must not be empty."
  }
}

variable "cors_enabled" {
  description = "Whether to include CORS response headers."
  type        = bool
  default     = false
}

variable "cors_allow_origin" {
  description = "Access-Control-Allow-Origin value when CORS is enabled."
  type        = string
  default     = "*"

  validation {
    condition     = length(trimspace(var.cors_allow_origin)) > 0
    error_message = "cors_allow_origin must not be empty."
  }
}

variable "cors_allow_methods" {
  description = "Access-Control-Allow-Methods values when CORS is enabled."
  type        = list(string)
  default     = ["GET", "HEAD", "OPTIONS"]

  validation {
    condition     = length(var.cors_allow_methods) > 0 && alltrue([for method in var.cors_allow_methods : can(regex("^[A-Z]+$", method))])
    error_message = "cors_allow_methods must contain uppercase HTTP methods."
  }
}

variable "cors_allow_headers" {
  description = "Access-Control-Allow-Headers values when CORS is enabled."
  type        = list(string)
  default     = ["Content-Type", "Accept", "X-Requested-With", "Authorization"]

  validation {
    condition     = length(var.cors_allow_headers) > 0 && alltrue([for header in var.cors_allow_headers : length(trimspace(header)) > 0])
    error_message = "cors_allow_headers must not contain empty strings."
  }
}

variable "additional_response_headers" {
  description = "Additional static response headers returned by the Lambda function."
  type        = map(string)
  default     = {}
}

variable "lambda_environment_variables" {
  description = "Additional Lambda environment variables. Values here override module-generated variables with the same key."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Additional tags applied to resources."
  type        = map(string)
  default     = {}
}
