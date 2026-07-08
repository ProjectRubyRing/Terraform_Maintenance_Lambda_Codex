env        = "pr"
aws_region = "ap-northeast-1"

system_name = "sampleapp"
name_prefix = "pr"

listener_arn           = "arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:listener/app/sample-pr-alb/50dc6c495c0c9188/f2f7dc8efc522ab2"
listener_rule_priority = 50

host_header_values = [
  "www.example.com",
  "api.example.com"
]
path_pattern_values = ["/*"]

http_header_conditions  = []
query_string_conditions = []

api_path_prefixes = ["/api", "/internal-api"]

maintenance_title   = "Scheduled Maintenance"
maintenance_message = "The service is temporarily unavailable due to scheduled maintenance."
maintenance_detail  = "Please retry after the maintenance window. Contact the operations team if this message continues after the announced window."

status_code         = 503
retry_after_seconds = 900

cors_enabled      = true
cors_allow_origin = "https://www.example.com"

inline_css = true
css_path   = "/maintenance.css"

log_retention_days     = 365
log_group_skip_destroy = true

tags = {
  Owner         = "platform"
  TerraformRoot = "envs/pr"
  Criticality   = "production"
}
