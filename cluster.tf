module "general_cluster_nodes" {
  source                    = "./modules/cluster_nodes"
  replica                   = 1
  cluster_name              = var.cluster_name
  name                      = "general"
  instance_type             = var.instance_type
  autoscaling_min_instances = var.autoscaling_min_instances
  autoscaling_max_instances = var.autoscaling_max_instances

  iam_instance_profile = aws_iam_instance_profile.ecs_agent.arn
  security_groups      = [module.ec2_security_group.security_group_id]
  vpc_zone_identifier  = module.ecs_vpc.public_subnets # TODO: consult on validity of chosen subnets

  user_data = <<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config
EOF
}

# ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.cluster_name}-cluster"
}
resource "aws_ecs_cluster_capacity_providers" "capacity_providers" {
  cluster_name = aws_ecs_cluster.ecs_cluster.name
  capacity_providers = flatten([
    [module.general_cluster_nodes.capacity_provider_name],
    [for cluster_nodes in module.indexed_search_cluster_nodes : cluster_nodes.capacity_provider_name],
  ])

  default_capacity_provider_strategy {
    capacity_provider = module.general_cluster_nodes.capacity_provider_name
    weight            = "1"
  }
}

resource "aws_cloudwatch_log_group" "primary" {
  name              = var.cluster_name
  retention_in_days = 90
}

data "aws_caller_identity" "current" {}
locals {
  aws_account_id = data.aws_caller_identity.current.account_id
}
