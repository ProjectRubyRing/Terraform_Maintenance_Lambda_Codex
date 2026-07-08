# ALB Maintenance Lambda

## 設計概要

このリポジトリは、AWS ALB のメンテナンス応答経路を構築します。既存の ALB リスナールールで対象リクエストを Lambda ターゲットグループへ転送します。Lambda 関数は Python 3.13 で動作し、ALB Lambda ターゲット用のレスポンス形式を直接返します。

構成イメージ:

```text
Client
  -> ALB listener
    -> listener rule conditions
      -> Lambda target group
        -> Python 3.13 Lambda
          -> HTML maintenance page, standalone CSS, or JSON API error
          -> CloudWatch Logs
```

Lambda パッケージに含まれるファイルは `lambda_function.py`、`maintenance.html`、`maintenance.css` のみです。既存の HTML/CSS は、Terraform の構成を変更せずに `modules/alb_maintenance_lambda/src/` 配下で差し替えられます。

## ディレクトリ構成

```text
.
|-- modules/
|   `-- alb_maintenance_lambda/
|       |-- versions.tf
|       |-- variables.tf
|       |-- main.tf
|       |-- outputs.tf
|       |-- locals.tf
|       |-- src/
|       |   |-- lambda_function.py
|       |   |-- maintenance.html
|       |   `-- maintenance.css
|       `-- README.md
|-- envs/
|   |-- j1/
|   |   |-- versions.tf
|   |   |-- backend.tf
|   |   |-- provider.tf
|   |   |-- main.tf
|   |   |-- variables.tf
|   |   |-- terraform.tfvars
|   |   `-- outputs.tf
|   |-- j2/
|   |-- j3/
|   |-- st/
|   `-- pr/
|-- test/
|   |-- events/
|   |   |-- alb_html_request.json
|   |   |-- alb_api_request_by_path.json
|   |   |-- alb_api_request_by_accept_header.json
|   |   `-- alb_css_request.json
|   |-- local_invoke.py
|   |-- test_lambda_function.py
|   `-- run_local_test.sh
|-- container-test/
|   |-- Dockerfile
|   |-- run_container_test.sh
|   `-- curl_invoke_examples.sh
`-- README.md
```

## Terraform モジュールの使い方

環境ルートから `modules/alb_maintenance_lambda` を使用します。

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

このモジュールは次のリソースを作成します。

- Lambda 関数とデプロイ用 ZIP
- Lambda 実行ロール
- CloudWatch Logs ロググループ
- ALB Lambda ターゲットグループ
- ALB からの Lambda 実行許可
- ターゲットグループアタッチメント
- ALB リスナールール

## 環境ごとの適用フロー

各環境は `envs/j1`、`envs/j2`、`envs/j3`、`envs/st`、`envs/pr` 配下にあります。

初回実行前に、各環境の `backend.tf` と `terraform.tfvars` サンプルを編集してください。

- S3 バックエンドバケット名と DynamoDB ロックテーブル名を置き換える。
- `listener_arn` を実際のリスナー ARN に置き換える。
- 対象リスナー内で一意な `listener_rule_priority` を設定する。
- シークレットは `terraform.tfvars` に入れない。機密値には IAM ロール、SSM Parameter Store、Secrets Manager、または CI 変数を使用する。

j1 の例:

```bash
cd envs/j1
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

`envs/j2`、`envs/j3`、`envs/st`、`envs/pr` でも同じ流れを繰り返します。

## HTML と CSS の差し替え

次のファイルを差し替えます。

- `modules/alb_maintenance_lambda/src/maintenance.html`
- `modules/alb_maintenance_lambda/src/maintenance.css`

HTML テンプレートは次のプレースホルダーに対応しています。

- `{{TITLE}}`
- `{{MESSAGE}}`
- `{{DETAIL}}`
- `{{CSS}}`

`inline_css = true` の場合、`{{CSS}}` は `<style>` ブロックになります。`inline_css = false` の場合、`{{CSS}}` は `css_path` へのスタイルシートリンクになり、そのパスへのリクエストでは CSS ファイルを `text/css; charset=utf-8` として返します。

## API 判定

有効な判定条件のいずれかに一致した場合、Lambda は JSON を返します。

- パスが `api_path_prefixes` のいずれかの値で始まる
- `Accept` に `application/json` が含まれる
- `Content-Type` に `application/json` が含まれる
- `X-Requested-With` が `XMLHttpRequest` と等しい

これらは Terraform 変数で変更できます。

- `api_path_prefixes`
- `api_detect_accept_json`
- `api_detect_content_type_json`
- `api_detect_x_requested_with`

ルートモジュールは `api_path_prefixes` を公開しています。高度な判定トグルは、ルート変数を拡張するか、再利用モジュールの `lambda_environment_variables` を直接使用して渡せます。

## レスポンスヘッダー

Lambda は次のヘッダーを返します。

- `Content-Type`
- `Cache-Control`
- `retry_after_seconds > 0` の場合は `Retry-After`
- `cors_enabled = true` の場合は CORS ヘッダー

デフォルトステータスは `503 Service Unavailable` です。ALB メンテナンス動作として別のコードが意図的に必要な場合のみ、`status_code` で変更してください。

## リスナールール優先度の注意点

ALB リスナーの優先度は、リスナーごとに一意である必要があります。数値が小さいほど先に評価されます。広範なアプリケーション転送ルールより前に、対象を絞ったメンテナンスルールを配置してください。j1、j2、j3、st、pr が同じリスナーを共有する場合、同じ優先度を使い回さないでください。本番では、適用前に ALB コンソールまたは `aws elbv2 describe-rules` で実際のルール順序を確認してください。

## RHEL9 でのローカルユニットテスト

ローカルテストに AWS 認証情報や Terraform apply は不要です。

```bash
bash test/run_local_test.sh
```

このスクリプトは、利用可能な場合は `python3.13` を使用し、なければ `python3` にフォールバックします。次のリクエストを実行します。

- HTML リクエスト
- パスによる API リクエスト
- CSS リクエスト

pytest がインストールされている場合は、次も実行します。

```bash
python3 -m pytest test/test_lambda_function.py
```

直接ローカル実行する例:

```bash
python3 test/local_invoke.py --event test/events/alb_html_request.json --assert-status 503 --assert-content-type text/html
python3 test/local_invoke.py --event test/events/alb_api_request_by_accept_header.json --assert-status 503 --assert-content-type application/json
python3 test/local_invoke.py --event test/events/alb_css_request.json --assert-status 503 --assert-content-type text/css
```

## コンテナ Lambda テスト

コンテナテストでは、AWS Lambda Python 3.13 ベースイメージを使用し、ローカル Runtime Interface Emulator エンドポイントを HTTP で呼び出します。

```bash
bash container-test/run_container_test.sh
```

このスクリプトは Docker を先に検出し、その後 Podman を検出します。イメージをビルドし、ポート 9000 でコンテナを起動し、curl で HTML/API/CSS イベントを呼び出して `statusCode` と `headers.Content-Type` を検証したあと、コンテナを停止します。

コンテナ起動後の手動 curl 例:

```bash
curl -s -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d @test/events/alb_html_request.json
```

Podman でも同じイメージとコマンドを実行できます。

```bash
podman build -f container-test/Dockerfile -t alb-maintenance-lambda-test:latest .
podman run --rm -p 9000:8080 alb-maintenance-lambda-test:latest
```

## 本番適用チェックリスト

- ALB リスナー ARN がステージングではなく本番のものであることを確認する。
- `listener_rule_priority` が既存の本番ルールと競合しないことを確認する。
- ホスト条件とパス条件が、意図したメンテナンス範囲だけに一致することを確認する。
- ロールバック用に通常のアプリケーションターゲットルールが残っていることを確認する。
- `retry_after_seconds`、CORS オリジン、ステータスコードがクライアントにとって許容できることを確認する。
- `pr` のバックエンドバケット、ロックテーブル、AWS アカウントが本番用であることを確認する。
- `log_group_skip_destroy = true` と長期ログ保持が意図した設定であることを確認する。
- plan/apply 前にローカルテストとコンテナテストを実行する。
- `terraform plan` を慎重にレビューし、承認されたメンテナンス時間帯にのみ apply する。

## トラブルシューティング

- ALB が 502 を返す: Lambda レスポンス形式、特に `statusCode`、`statusDescription`、`headers`、`body`、`isBase64Encoded` を確認する。
- HTML に CSS が反映されない: `inline_css` と `css_path` を確認する。外部 CSS を使用する場合は、ALB ルールが CSS パスもこの Lambda に転送することを確認する。
- ページリクエストで JSON が返る: `Accept`、`Content-Type`、`X-Requested-With`、`api_path_prefixes` を確認する。
- Lambda が呼び出されない: リスナールール優先度、ルール条件、ターゲットグループアタッチメント、`aws_lambda_permission` の source ARN を確認する。
- Terraform バックエンドエラー: `terraform init` の前に、サンプルの S3 バックエンド値を置き換える。
