output "lambda_function_arn" {
  description = "ARN of the maintenance Lambda function."
  value       = aws_lambda_function.maintenance.arn
}

output "lambda_function_name" {
  description = "Name of the maintenance Lambda function."
  value       = aws_lambda_function.maintenance.function_name
}

output "target_group_arn" {
  description = "ARN of the ALB Lambda target group."
  value       = aws_lb_target_group.lambda.arn
}

output "listener_rule_arn" {
  description = "ARN of the ALB listener rule."
  value       = aws_lb_listener_rule.maintenance.arn
}

output "log_group_name" {
  description = "CloudWatch Logs log group name for the Lambda function."
  value       = aws_cloudwatch_log_group.lambda.name
}
