# alb_maintenance_lambda module

This module creates a Python 3.13 Lambda function for ALB Lambda target groups and wires it to an existing ALB listener rule.

## Created Resources

- Lambda function with `lambda_function.handler`
- Lambda execution role and least-privilege CloudWatch Logs policy
- CloudWatch Logs log group
- ZIP deployment package from `src/lambda_function.py`, `src/maintenance.html`, and `src/maintenance.css`
- ALB Lambda target group
- `aws_lambda_permission` allowing ALB to invoke the function
- Target group attachment
- ALB listener rule forwarding matched requests to the Lambda target group

## Minimal Usage

```hcl
module "alb_maintenance_lambda" {
  source = "../../modules/alb_maintenance_lambda"

  env                    = "j1"
  system_name            = "sampleapp"
  listener_arn           = "arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:listener/app/example/aaa/bbb"
  listener_rule_priority = 100
  host_header_values     = ["j1.example.com"]
  path_pattern_values    = ["/*"]
}
```

## API Detection

Lambda treats a request as an API request when any enabled detector matches:

- Path starts with one of `api_path_prefixes`
- `Accept` header includes `application/json`
- `Content-Type` header includes `application/json`
- `X-Requested-With` is `XMLHttpRequest`

The detectors are controlled by Terraform variables and passed to Lambda as environment variables.

## CSS Modes

`inline_css = true` embeds `maintenance.css` into the HTML response through `{{CSS}}`.

`inline_css = false` renders a stylesheet link to `css_path`. Requests to that exact path return `maintenance.css` as `text/css; charset=utf-8`.

## ALB Response Notes

ALB Lambda targets expect a flat response object containing `statusCode`, `statusDescription`, `isBase64Encoded`, `headers`, and `body`. This Lambda intentionally uses normal `headers` rather than `multiValueHeaders` because the target group is created with `lambda_multi_value_headers_enabled = false`.
