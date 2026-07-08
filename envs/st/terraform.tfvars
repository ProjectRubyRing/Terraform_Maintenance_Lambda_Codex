env        = "st"
aws_region = "ap-northeast-1"

system_name = "sampleapp"
name_prefix = "st"

listener_arn           = "arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:listener/app/sample-st-alb/50dc6c495c0c9188/f2f7dc8efc522ab2"
listener_rule_priority = 201

host_header_values  = ["st.example.com"]
path_pattern_values = ["/*"]

http_header_conditions = [
  {
    name   = "X-Maintenance-Mode"
    values = ["on"]
  }
]
query_string_conditions = []

api_path_prefixes = ["/api", "/internal-api"]

maintenance_title   = "ST Maintenance"
maintenance_message = "Staging environment is temporarily unavailable due to maintenance."
maintenance_detail  = "Validate maintenance behavior here before applying production changes."

status_code         = 503
retry_after_seconds = 600

cors_enabled      = true
cors_allow_origin = "https://st.example.com"

inline_css = false
css_path   = "/maintenance.css"

log_retention_days     = 30
log_group_skip_destroy = false

tags = {
  Owner         = "platform"
  TerraformRoot = "envs/st"
}
