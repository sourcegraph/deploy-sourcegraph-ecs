variable "replica" { type = number }
variable "cluster_name" { type = string }
variable "name" { type = string }
variable "iam_instance_profile" { type = string }
variable "security_groups" { type = set(string) }
variable "vpc_zone_identifier" { type = set(string) }
variable "user_data" { type = string }
variable "instance_type" { type = string }
variable "ebs_block_device" {
  type = object({
    device_name           = string
    volume_size           = number
    volume_type           = string
    delete_on_termination = bool
    encrypted             = bool
  })
  default = null
}
variable "autoscaling_min_instances" { type = number }
variable "autoscaling_max_instances" { type = number }

output "launch_configuration_name" {
  value = aws_launch_configuration.this.name
}
output "autoscaling_group_arn" {
  value = aws_autoscaling_group.this.arn
}
output "capacity_provider_name" {
  value = aws_ecs_capacity_provider.this.name
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

resource "aws_launch_configuration" "this" {
  name_prefix          = "${var.cluster_name}-${var.name}-${var.replica}"
  image_id             = data.aws_ami.aws_optimized_ecs.id
  instance_type        = var.instance_type
  iam_instance_profile = var.iam_instance_profile
  security_groups      = var.security_groups
  ebs_optimized        = true
  enable_monitoring    = true
  dynamic "ebs_block_device" {
    for_each = var.ebs_block_device[*]
    iterator = this
    content {
      device_name           = this.value.device_name
      volume_size           = this.value.volume_size
      volume_type           = this.value.volume_type
      delete_on_termination = this.value.delete_on_termination
      encrypted             = this.value.encrypted
    }
  }
  lifecycle {
    create_before_destroy = true
  }
  user_data = var.user_data
}

# Auto-scaling group used to create EC2 instances in our ECS cluster.
resource "aws_autoscaling_group" "this" {
  name_prefix = "${var.cluster_name}-${var.name}-${var.replica}"
  termination_policies = [
    "AllocationStrategy",
    "OldestInstance"
  ]
  default_cooldown      = 120 # Time in seconds after a scaling activity completes before another scaling activity can start.
  max_size              = var.autoscaling_max_instances
  min_size              = var.autoscaling_min_instances
  protect_from_scale_in = true

  launch_configuration = aws_launch_configuration.this.name

  lifecycle {
    create_before_destroy = true
  }
  vpc_zone_identifier = var.vpc_zone_identifier

  # TODO: cleanup tags
  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "this" {
  name = "${var.cluster_name}-${var.name}-${var.replica}"
  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.this.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 1000
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}
