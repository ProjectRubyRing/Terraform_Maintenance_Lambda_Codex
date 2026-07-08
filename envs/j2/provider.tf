provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      var.tags,
      {
        Environment = var.env
        System      = var.system_name
      }
    )
  }
}
