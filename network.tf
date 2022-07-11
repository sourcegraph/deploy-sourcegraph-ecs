# AWS network configuration

module "ecs_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway     = true
  enable_dns_hostnames   = true
  one_nat_gateway_per_az = true
}

module "ec2_security_group" {
  source = "terraform-aws-modules/security-group/aws"

  name   = "${var.cluster_name}-ec2-security-group"
  vpc_id = module.ecs_vpc.vpc_id

  ingress_with_cidr_blocks = [
    {                    # TODO
      from_port   = 9238 #80
      to_port     = 9238 #80
      protocol    = "tcp"
      description = "http port"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = var.ssh_port #22
      to_port     = var.ssh_port #22
      protocol    = "tcp"
      description = "ssh port"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  # TODO: restrict this / document how to
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}
