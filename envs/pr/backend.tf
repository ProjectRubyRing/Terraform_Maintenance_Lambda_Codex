terraform {
  backend "s3" {
    bucket         = "example-terraform-state-pr"
    key            = "alb-maintenance-lambda/pr/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "example-terraform-locks-pr"
  }
}
