# AWS network configuration

# ECS cluster
resource "aws_ecs_cluster" "ecs-cluster" {
  name = "${var.prefix}-cluster"
}

# VPC
resource "aws_vpc" "aws-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}
