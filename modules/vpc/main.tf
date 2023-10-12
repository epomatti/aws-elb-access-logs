data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  aws_region = data.aws_region.current.name

  availability_zone_1 = "${local.aws_region}a"
  availability_zone_2 = "${local.aws_region}b"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_default_route_table" "public" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = local.availability_zone_1

  # Auto-assign public IPv4 address
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = local.availability_zone_2

  # Auto-assign public IPv4 address
  map_public_ip_on_launch = true
}

# This will clean up all default entries
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
}
