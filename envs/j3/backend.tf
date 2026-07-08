terraform {
  backend "s3" {
    bucket         = "example-terraform-state-j3"
    key            = "alb-maintenance-lambda/j3/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "example-terraform-locks-j3"
  }
}
