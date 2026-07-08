terraform {
  backend "s3" {
    bucket         = "example-terraform-state-st"
    key            = "alb-maintenance-lambda/st/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "example-terraform-locks-st"
  }
}
