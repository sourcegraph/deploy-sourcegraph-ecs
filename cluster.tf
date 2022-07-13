# Launch configuration for our EC2 instances in our ECS cluster.
resource "aws_launch_configuration" "launch_configuration" {
  name_prefix   = "${var.cluster_name}-ecs-cluster"
  image_id      = data.aws_ami.aws_optimized_ecs.id
  instance_type = var.instance_type

  # TODO
  associate_public_ip_address = true
  lifecycle {
    create_before_destroy = true
  }
  user_data = <<EOF
#!/bin/bash
echo ECS_CLUSTER=${var.cluster_name}-cluster >> /etc/ecs/ecs.config
EOF

  security_groups      = [module.ec2_security_group.security_group_id]
  iam_instance_profile = aws_iam_instance_profile.ecs_agent.arn
}


# The AMI our ECS cluster's EC2 instances will run (Amazon's ECS-optimized AMI)
data "aws_ami" "aws_optimized_ecs" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami*amazon-ecs-optimized"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["591542846629"] # AWS
}


# Auto-scaling group used to create EC2 instances in our ECS cluster.
resource "aws_autoscaling_group" "autoscaling_group" {
  name_prefix = "${var.cluster_name}-autoscaling-group"
  termination_policies = [
    "AllocationStrategy",
    "OldestInstance"
  ]
  default_cooldown      = 120 # Time in seconds after a scaling activity completes before another scaling activity can start.
  max_size              = var.autoscaling_max_instances
  min_size              = var.autoscaling_min_instances
  protect_from_scale_in = true

  launch_configuration = aws_launch_configuration.launch_configuration.name

  lifecycle {
    create_before_destroy = true
  }
  vpc_zone_identifier = module.ecs_vpc.public_subnets # TODO: consult on validity of chosen subnets

  # TODO: cleanup tags
  tags = [
    {
      key                 = "AmazonECSManaged"
      value               = true
      propagate_at_launch = true
    },
    {
      key                 = "Name"
      value               = var.cluster_name,
      propagate_at_launch = true
    }
  ]
}


# ECS capacity provider (causes autoscaling group instances to register with our ECS cluster)
resource "aws_ecs_capacity_provider" "capacity_provider" {
  name = "${var.cluster_name}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.autoscaling_group.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 1000
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}


# ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.cluster_name}-cluster"
}
resource "aws_ecs_cluster_capacity_providers" "capacity_providers" {
  cluster_name       = aws_ecs_cluster.ecs_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.capacity_provider.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.capacity_provider.name
    weight            = "1"
  }
}

data "aws_caller_identity" "current" {}
locals {
  aws_account_id = data.aws_caller_identity.current.account_id
}
