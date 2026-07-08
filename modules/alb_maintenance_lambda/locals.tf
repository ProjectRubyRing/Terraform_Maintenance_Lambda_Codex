locals {
  name_prefix_parts = concat(
    var.name_prefix == null || trimspace(var.name_prefix) == "" ? [] : [var.name_prefix],
    [var.system_name, var.env, "maintenance"]
  )

  base_name         = lower(join("-", local.name_prefix_parts))
  function_name     = var.lambda_function_name == null || trimspace(var.lambda_function_name) == "" ? substr(local.base_name, 0, 64) : var.lambda_function_name
  target_group_name = var.target_group_name == null || trimspace(var.target_group_name) == "" ? substr("${local.base_name}-tg", 0, 32) : var.target_group_name
  log_group_name    = "/aws/lambda/${local.function_name}"

  common_tags = merge(
    {
      Environment = var.env
      System      = var.system_name
      Component   = "alb-maintenance-lambda"
      ManagedBy   = "terraform"
    },
    var.tags
  )

  default_lambda_environment_variables = {
    MAINTENANCE_TITLE            = var.maintenance_title
    MAINTENANCE_MESSAGE          = var.maintenance_message
    MAINTENANCE_DETAIL           = var.maintenance_detail
    STATUS_CODE                  = tostring(var.status_code)
    RETRY_AFTER_SECONDS          = tostring(var.retry_after_seconds)
    CACHE_CONTROL                = var.cache_control
    CSS_INLINE                   = tostring(var.inline_css)
    CSS_PATH                     = var.css_path
    API_PATH_PREFIXES            = join(",", var.api_path_prefixes)
    API_DETECT_ACCEPT_JSON       = tostring(var.api_detect_accept_json)
    API_DETECT_CONTENT_TYPE_JSON = tostring(var.api_detect_content_type_json)
    API_DETECT_X_REQUESTED_WITH  = tostring(var.api_detect_x_requested_with)
    API_ERROR_CODE               = var.api_error_code
    API_ERROR_MESSAGE            = var.api_error_message
    CORS_ENABLED                 = tostring(var.cors_enabled)
    CORS_ALLOW_ORIGIN            = var.cors_allow_origin
    CORS_ALLOW_METHODS           = join(",", var.cors_allow_methods)
    CORS_ALLOW_HEADERS           = join(",", var.cors_allow_headers)
    ADDITIONAL_RESPONSE_HEADERS  = jsonencode(var.additional_response_headers)
  }

  lambda_environment_variables = merge(
    local.default_lambda_environment_variables,
    var.lambda_environment_variables
  )
}
