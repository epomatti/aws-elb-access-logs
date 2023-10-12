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

module "ec2" {
  source        = "./modules/ec2"
  app           = local.app
  image_id      = var.ami
  instance_type = var.instance_type
  vpc_id        = module.vpc.vpc_id
}
