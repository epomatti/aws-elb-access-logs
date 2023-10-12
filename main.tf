terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.20.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  app = "companyx"
}

module "vpc" {
  source = "./modules/vpc"
  app    = local.app
}

module "bucket" {
  source         = "./modules/bucket"
  app            = local.app
  elb_account_id = var.elb_account_id
}
