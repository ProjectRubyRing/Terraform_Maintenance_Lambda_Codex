terraform {
  backend "s3" {
    bucket         = "example-terraform-state-j2"
    key            = "alb-maintenance-lambda/j2/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "example-terraform-locks-j2"
  }
}
