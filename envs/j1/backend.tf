terraform {
  backend "s3" {
    bucket         = "example-terraform-state-j1"
    key            = "alb-maintenance-lambda/j1/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "example-terraform-locks-j1"
  }
}
