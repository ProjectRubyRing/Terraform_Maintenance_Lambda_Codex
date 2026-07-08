output "lambda_function_arn" {
  description = "Maintenance Lambda function ARN."
  value       = module.alb_maintenance_lambda.lambda_function_arn
}

output "lambda_function_name" {
  description = "Maintenance Lambda function name."
  value       = module.alb_maintenance_lambda.lambda_function_name
}

output "target_group_arn" {
  description = "ALB Lambda target group ARN."
  value       = module.alb_maintenance_lambda.target_group_arn
}

output "listener_rule_arn" {
  description = "ALB listener rule ARN."
  value       = module.alb_maintenance_lambda.listener_rule_arn
}

output "log_group_name" {
  description = "Lambda CloudWatch Logs log group name."
  value       = module.alb_maintenance_lambda.log_group_name
}
