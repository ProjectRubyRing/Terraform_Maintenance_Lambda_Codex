module "alb_maintenance_lambda" {
  source = "../../modules/alb_maintenance_lambda"

  env                    = var.env
  system_name            = var.system_name
  name_prefix            = var.name_prefix
  listener_arn           = var.listener_arn
  listener_rule_priority = var.listener_rule_priority

  host_header_values      = var.host_header_values
  path_pattern_values     = var.path_pattern_values
  http_header_conditions  = var.http_header_conditions
  query_string_conditions = var.query_string_conditions

  api_path_prefixes   = var.api_path_prefixes
  maintenance_title   = var.maintenance_title
  maintenance_message = var.maintenance_message
  maintenance_detail  = var.maintenance_detail
  status_code         = var.status_code
  retry_after_seconds = var.retry_after_seconds
  cors_enabled        = var.cors_enabled
  cors_allow_origin   = var.cors_allow_origin
  inline_css          = var.inline_css
  css_path            = var.css_path

  log_retention_days     = var.log_retention_days
  log_group_skip_destroy = var.log_group_skip_destroy
  tags                   = var.tags
}
