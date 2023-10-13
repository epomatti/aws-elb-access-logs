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

data "aws_caller_identity" "current" {}

locals {
  app                = "companyx"
  access_logs_prefix = "elb-accesslogs"
  account_id         = data.aws_caller_identity.current.account_id
}

module "vpc" {
  source = "./modules/vpc"
  app    = local.app
}

module "bucket" {
  source             = "./modules/bucket"
  app                = local.app
  elb_account_id     = var.elb_account_id
  access_logs_prefix = local.access_logs_prefix
}

module "ec2" {
  source        = "./modules/ec2"
  app           = local.app
  image_id      = var.ami
  instance_type = var.instance_type
  vpc_id        = module.vpc.vpc_id

  depends_on = [module.bucket]
}

module "elb" {
  source = "./modules/elb"
  app    = local.app

  vpc_id                 = module.vpc.vpc_id
  ec2_launch_template_id = module.ec2.lanch_template_id
  subnet_ids             = module.vpc.subnet_ids

  access_logs_enabled = var.elb_access_logs_enabled
  access_logs_prefix  = local.access_logs_prefix
  access_logs_bucket  = module.bucket.bucket
}

module "athena" {
  source     = "./modules/athena"
  account_id = local.account_id
  principal  = var.athena_user_principal
}

module "glue" {
  source = "./modules/glue"
}
