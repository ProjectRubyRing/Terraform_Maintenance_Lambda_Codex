env        = "j3"
aws_region = "ap-northeast-1"

system_name = "sampleapp"
name_prefix = "j3"

listener_arn           = "arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:listener/app/sample-j3-alb/50dc6c495c0c9188/f2f7dc8efc522ab2"
listener_rule_priority = 103

host_header_values  = ["j3.example.com"]
path_pattern_values = ["/*"]

http_header_conditions  = []
query_string_conditions = []

api_path_prefixes = ["/api", "/internal-api"]

maintenance_title   = "J3 Maintenance"
maintenance_message = "J3 environment is temporarily unavailable due to maintenance."
maintenance_detail  = "This message is returned by the ALB maintenance Lambda."

status_code         = 503
retry_after_seconds = 300

cors_enabled      = true
cors_allow_origin = "*"

inline_css = true
css_path   = "/maintenance.css"

log_retention_days     = 14
log_group_skip_destroy = false

tags = {
  Owner         = "platform"
  TerraformRoot = "envs/j3"
}
