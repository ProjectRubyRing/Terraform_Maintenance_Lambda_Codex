# ALB Maintenance Lambda

## Design Overview

This repository builds an AWS ALB maintenance response path. An existing ALB listener rule forwards selected requests to a Lambda target group. The Lambda function runs on Python 3.13 and returns the ALB Lambda target response shape directly.

Text architecture:

```text
Client
  -> ALB listener
    -> listener rule conditions
      -> Lambda target group
        -> Python 3.13 Lambda
          -> HTML maintenance page, standalone CSS, or JSON API error
          -> CloudWatch Logs
```

The Lambda package contains only `lambda_function.py`, `maintenance.html`, and `maintenance.css`. Existing HTML/CSS can be replaced in `modules/alb_maintenance_lambda/src/` without changing Terraform structure.

## Directory Tree

```text
.
├── modules/
│   └── alb_maintenance_lambda/
│       ├── versions.tf
│       ├── variables.tf
│       ├── main.tf
│       ├── outputs.tf
│       ├── locals.tf
│       ├── src/
│       │   ├── lambda_function.py
│       │   ├── maintenance.html
│       │   └── maintenance.css
│       └── README.md
├── envs/
│   ├── j1/
│   │   ├── versions.tf
│   │   ├── backend.tf
│   │   ├── provider.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── outputs.tf
│   ├── j2/
│   ├── j3/
│   ├── st/
│   └── pr/
├── test/
│   ├── events/
│   │   ├── alb_html_request.json
│   │   ├── alb_api_request_by_path.json
│   │   ├── alb_api_request_by_accept_header.json
│   │   └── alb_css_request.json
│   ├── local_invoke.py
│   ├── test_lambda_function.py
│   └── run_local_test.sh
├── container-test/
│   ├── Dockerfile
│   ├── run_container_test.sh
│   └── curl_invoke_examples.sh
└── README.md
```

## Terraform Module Usage

Use `modules/alb_maintenance_lambda` from an environment root:

```hcl
module "alb_maintenance_lambda" {
  source = "../../modules/alb_maintenance_lambda"

  env                    = var.env
  system_name            = var.system_name
  listener_arn           = var.listener_arn
  listener_rule_priority = var.listener_rule_priority
  host_header_values     = var.host_header_values
  path_pattern_values    = var.path_pattern_values
}
```

The module creates:

- Lambda function and deployment ZIP
- Lambda execution role
- CloudWatch Logs log group
- ALB Lambda target group
- Lambda invoke permission for ALB
- Target group attachment
- ALB listener rule

## Environment Apply Flow

Each environment is under `envs/j1`, `envs/j2`, `envs/j3`, `envs/st`, and `envs/pr`.

Before the first run, edit each `backend.tf` and `terraform.tfvars` sample:

- Replace S3 backend bucket and DynamoDB lock table names.
- Replace `listener_arn` with the real listener ARN.
- Set unique `listener_rule_priority` values in the target listener.
- Keep secrets outside `terraform.tfvars`. Use IAM roles, SSM Parameter Store, Secrets Manager, or CI variables for sensitive values.

Example for j1:

```bash
cd envs/j1
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Repeat the same flow from `envs/j2`, `envs/j3`, `envs/st`, and `envs/pr`.

## HTML and CSS Replacement

Replace these files:

- `modules/alb_maintenance_lambda/src/maintenance.html`
- `modules/alb_maintenance_lambda/src/maintenance.css`

The HTML template supports:

- `{{TITLE}}`
- `{{MESSAGE}}`
- `{{DETAIL}}`
- `{{CSS}}`

When `inline_css = true`, `{{CSS}}` becomes a `<style>` block. When `inline_css = false`, `{{CSS}}` becomes a stylesheet link to `css_path`, and requests to that path return the CSS file as `text/css; charset=utf-8`.

## API Detection

Lambda returns JSON when any enabled detector matches:

- Path starts with a value from `api_path_prefixes`
- `Accept` includes `application/json`
- `Content-Type` includes `application/json`
- `X-Requested-With` equals `XMLHttpRequest`

Change these with Terraform variables:

- `api_path_prefixes`
- `api_detect_accept_json`
- `api_detect_content_type_json`
- `api_detect_x_requested_with`

The root modules expose `api_path_prefixes`. Advanced detector toggles can be passed by extending root variables or by using `lambda_environment_variables` directly in the reusable module.

## Response Headers

The Lambda returns:

- `Content-Type`
- `Cache-Control`
- `Retry-After` when `retry_after_seconds > 0`
- CORS headers when `cors_enabled = true`

Default status is `503 Service Unavailable`. Change it with `status_code` only when the ALB maintenance behavior intentionally requires another code.

## Listener Rule Priority Notes

ALB listener priorities must be unique per listener. Lower numbers are evaluated first. Put precise maintenance rules before broad application forwarding rules. Avoid reusing the same priority across j1, j2, j3, st, and pr if they share a listener. For production, verify the effective rule order in the ALB console or with `aws elbv2 describe-rules` before applying.

## Local Unit Tests on RHEL9

The local tests do not require AWS credentials or Terraform apply.

```bash
bash test/run_local_test.sh
```

The script uses `python3.13` when available and falls back to `python3`. It invokes:

- HTML request
- API request by path
- CSS request

If pytest is installed, it also runs:

```bash
python3 -m pytest test/test_lambda_function.py
```

Direct local invoke examples:

```bash
python3 test/local_invoke.py --event test/events/alb_html_request.json --assert-status 503 --assert-content-type text/html
python3 test/local_invoke.py --event test/events/alb_api_request_by_accept_header.json --assert-status 503 --assert-content-type application/json
python3 test/local_invoke.py --event test/events/alb_css_request.json --assert-status 503 --assert-content-type text/css
```

## Container Lambda Test

The container test uses the AWS Lambda Python 3.13 base image and invokes the local Runtime Interface Emulator endpoint over HTTP.

```bash
bash container-test/run_container_test.sh
```

The script detects Docker first, then Podman. It builds the image, starts the container on port 9000, invokes HTML/API/CSS events with curl, verifies `statusCode` and `headers.Content-Type`, then stops the container.

Manual curl example after starting the container:

```bash
curl -s -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d @test/events/alb_html_request.json
```

Podman can run the same image and commands:

```bash
podman build -f container-test/Dockerfile -t alb-maintenance-lambda-test:latest .
podman run --rm -p 9000:8080 alb-maintenance-lambda-test:latest
```

## Production Checklist

- Confirm the ALB listener ARN is production and not staging.
- Confirm `listener_rule_priority` does not conflict with existing production rules.
- Confirm host and path conditions match only the intended maintenance scope.
- Confirm the normal application target rule remains available for rollback.
- Confirm `retry_after_seconds`, CORS origin, and status code are acceptable for clients.
- Confirm `pr` backend bucket, lock table, and AWS account are production.
- Confirm `log_group_skip_destroy = true` and long log retention are intentional.
- Run local and container tests before plan/apply.
- Review `terraform plan` carefully and apply only during the approved maintenance window.

## Troubleshooting

- ALB returns 502: check Lambda response shape, especially `statusCode`, `statusDescription`, `headers`, `body`, and `isBase64Encoded`.
- HTML appears without CSS: verify `inline_css` and `css_path`; if external CSS is used, ensure the ALB rule also forwards the CSS path to this Lambda.
- JSON is returned for a page request: check `Accept`, `Content-Type`, `X-Requested-With`, and `api_path_prefixes`.
- Lambda is not invoked: check the listener rule priority, rule conditions, target group attachment, and `aws_lambda_permission` source ARN.
- Terraform backend errors: replace sample S3 backend values before `terraform init`.
