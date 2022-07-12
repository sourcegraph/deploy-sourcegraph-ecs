# AWS network configuration

module "ecs_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.1"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway     = true
  enable_dns_hostnames   = true
  one_nat_gateway_per_az = true

  # TODO: tag all resources with cluster name, "Project": "Sourcegraph", "ManagedBy": "Terraform"?
  # tags = local.common_tags
  # locals {
  #   common_tags = {
  #     Project   = "Sourcegraph"
  #     Cluster   = var.cluster_name
  #     ManagedBy = "Terraform"
  #   }
  # }
}

module "ec2_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.9"

  name   = "${var.cluster_name}-ec2-security-group"
  vpc_id = module.ecs_vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "http port"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      # TODO: restrict this / document how to at least
      from_port   = var.ssh_port
      to_port     = var.ssh_port
      protocol    = "tcp"
      description = "ssh port"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  # TODO: restrict this / document how to at least
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}
