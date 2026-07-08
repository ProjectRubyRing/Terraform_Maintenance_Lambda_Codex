data "aws_partition" "current" {}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.root}/.terraform/${local.function_name}.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  skip_destroy      = var.log_group_skip_destroy
  tags              = local.common_tags
}

resource "aws_iam_role" "lambda" {
  name                 = var.lambda_role_name == null || trimspace(var.lambda_role_name) == "" ? substr("${local.function_name}-role", 0, 64) : var.lambda_role_name
  permissions_boundary = var.permissions_boundary
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_logs" {
  name = "${local.function_name}-logs"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteLambdaLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      }
    ]
  })
}

resource "aws_lambda_function" "maintenance" {
  function_name                  = local.function_name
  description                    = "ALB maintenance response Lambda for ${var.system_name} ${var.env}"
  role                           = aws_iam_role.lambda.arn
  handler                        = "lambda_function.handler"
  runtime                        = var.lambda_runtime
  architectures                  = var.lambda_architectures
  filename                       = data.archive_file.lambda.output_path
  source_code_hash               = data.archive_file.lambda.output_base64sha256
  memory_size                    = var.lambda_memory_size
  timeout                        = var.lambda_timeout
  reserved_concurrent_executions = var.reserved_concurrent_executions
  publish                        = var.publish

  environment {
    variables = local.lambda_environment_variables
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.lambda_logs
  ]

  tags = local.common_tags
}

resource "aws_lb_target_group" "lambda" {
  name                               = local.target_group_name
  target_type                        = "lambda"
  lambda_multi_value_headers_enabled = false
  tags                               = local.common_tags
}

resource "aws_lambda_permission" "allow_alb" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.maintenance.function_name
  principal     = "elasticloadbalancing.${data.aws_partition.current.dns_suffix}"
  source_arn    = aws_lb_target_group.lambda.arn
}

resource "aws_lb_target_group_attachment" "lambda" {
  target_group_arn = aws_lb_target_group.lambda.arn
  target_id        = aws_lambda_function.maintenance.arn

  depends_on = [
    aws_lambda_permission.allow_alb
  ]
}

resource "aws_lb_listener_rule" "maintenance" {
  listener_arn = var.listener_arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda.arn
  }

  dynamic "condition" {
    for_each = length(var.host_header_values) > 0 ? [var.host_header_values] : []
    content {
      host_header {
        values = condition.value
      }
    }
  }

  dynamic "condition" {
    for_each = length(var.path_pattern_values) > 0 ? [var.path_pattern_values] : []
    content {
      path_pattern {
        values = condition.value
      }
    }
  }

  dynamic "condition" {
    for_each = var.http_header_conditions
    content {
      http_header {
        http_header_name = condition.value.name
        values           = condition.value.values
      }
    }
  }

  dynamic "condition" {
    for_each = var.query_string_conditions
    content {
      query_string {
        key   = try(condition.value.key, null)
        value = condition.value.value
      }
    }
  }

  lifecycle {
    precondition {
      condition = (
        length(var.host_header_values) > 0 ||
        length(var.path_pattern_values) > 0 ||
        length(var.http_header_conditions) > 0 ||
        length(var.query_string_conditions) > 0
      )
      error_message = "At least one listener rule condition must be provided."
    }
  }

  tags = local.common_tags
}
