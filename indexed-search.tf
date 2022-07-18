
# indexed-search deployment strategy:
#
# 1. We create a single EC2 instance (via an ASG so it is recreated if it goes down) which joins the
#    ECS_CLUSTER and sets an attribute on the instance "com.sourcegraph.service": "indexed-search-1"
#    for each indexed-search replica.
# 2. We have a regular ECS task definition to deploy both Zoekt containers, they will use the EBS
#    volume attached to their EC2 instance host machine via a docker volume mount driver.
# 3. Our ECS task uses placement_constraints to ensure it is only scheduled to run on the EC2
#    instance with a specific com.sourcegraph.service attribute, so the EC2 instance is dedicated
#    to that indexed-search replica only, and the EBS volume for that EC2 instance is "pinned" and
#    the data will be persisted there.

resource "aws_launch_configuration" "indexed_search" {
  for_each = { for i in range(var.indexed_search_instances) : "${i}" => i }

  name_prefix          = "${var.cluster_name}-indexed-search-${each.key}"
  image_id             = data.aws_ami.aws_optimized_ecs.id
  instance_type        = var.indexed_search_instance_type
  iam_instance_profile = aws_iam_instance_profile.ecs_agent.arn
  security_groups      = [module.ec2_security_group.security_group_id]
  ebs_optimized        = true
  enable_monitoring    = true
  ebs_block_device {
    device_name           = "/dev/sda1"
    volume_size           = 200
    volume_type           = "gp2"
    delete_on_termination = false
    encrypted             = false
  }
  lifecycle {
    create_before_destroy = true
  }
  user_data = <<EOF
#!/bin/bash
echo ECS_CLUSTER=${var.cluster_name}-cluster >> /etc/ecs/ecs.config
echo ECS_INSTANCE_ATTRIBUTES='${jsonencode({ "com.sourcegraph.service" = "indexed-search-${each.key}" })}' >> /etc/ecs/ecs.config

sudo mkdir /data -p
sudo echo '/dev/sda1 /data xfs defaults 0 0' >> /etc/fstab
sudo mount -a
sudo chown 100:100 /data && sudo chmod 777 /data
EOF
}

# Auto-scaling group used to create a single EC2 instance for each indexed-search-N replica in our
# ECS cluster. An ASG is used to ensure that e.g. if the EC2 instance goes down, the ASG will create
# a new one. It always has size 1.
resource "aws_autoscaling_group" "indexed_search" {
  for_each = { for i in range(var.indexed_search_instances) : "${i}" => i }

  name_prefix = "${var.cluster_name}-indexed-search-${each.key}"
  termination_policies = [
    "AllocationStrategy",
    "OldestInstance"
  ]
  max_size              = 1
  min_size              = 1
  protect_from_scale_in = true

  launch_configuration = aws_launch_configuration.indexed_search[each.key].name

  lifecycle {
    create_before_destroy = true
  }
  # TODO: consult with team about subnets / vpcs
  vpc_zone_identifier = module.ecs_vpc.public_subnets

  # TODO: standardized tags
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
resource "aws_ecs_capacity_provider" "indexed_search" {
  for_each = { for i in range(var.indexed_search_instances) : "${i}" => i }

  name = "${var.cluster_name}-indexed-search-${each.key}"
  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.indexed_search[each.key].arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 1000
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_task_definition" "indexed_search" {
  for_each = { for i in range(var.indexed_search_instances) : "${i}" => i }

  family = "${var.cluster_name}-indexed-search-${each.key}"
  container_definitions = jsonencode([
    {
      requiresCompatibilities = "EC2"
      name                    = "search-indexer"
      image                   = "${local.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/sourcegraph-search-indexer:3.41.0"

      # zoekt-indexserver is CPU bound. The more CPU you allocate to it, the
      # lower lag between a new commit and it being indexed for search.
      cpu       = 8192 # 8 CPUs
      memory    = 8192 # 8 GiB
      essential = true
      portMappings = [
        {
          # only exposed to other Sourcegraph services
          hostPort      = 6072,
          protocol      = "tcp",
          containerPort = 6072
        }
      ]
      logConfiguration = {
        logDriver     = "awslogs"
        secretOptions = null
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.primary.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = var.cluster_name
        }
      }
      mountPoints = [
        {
          readOnly      = null,
          containerPath = "/data/index"
          sourceVolume  = "data"
        }
      ]
      environment = [
        { name = "SRC_FRONTEND_INTERNAL", value = "sourcegraph-frontend-internal:3090" }, # TODO: this value is wrong
        { name = "JAEGER_AGENT_HOST", value = "localhost" },                              # TODO: this value is wrong
        # Tell this container the hostname of it's service (container pair). For example,
        # indexed-search-1 should would be a single indexed-search service, comprised of both a
        # single search-indexer and indexed-searcher containers. The hostname should be identical
        # for both, used for sharding / automatic rebalancing.
        { name = "HOSTNAME", value = "indexed-search-${each.key}" }
      ]
    },
    {
      requiresCompatibilities = "EC2"
      name                    = "indexed-searcher"
      image                   = "${local.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/sourcegraph-indexed-searcher:3.41.0"
      cpu                     = 2048 # 2 CPUs
      memory                  = 4092 # 4 GiB
      essential               = true
      portMappings = [
        {
          # only exposed to other Sourcegraph services
          hostPort      = 6070,
          protocol      = "tcp",
          containerPort = 6070
        }
      ]
      logConfiguration = {
        logDriver     = "awslogs"
        secretOptions = null
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.primary.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = var.cluster_name
        }
      }
      mountPoints = [
        {
          readOnly      = null,
          containerPath = "/data/index"
          sourceVolume  = "data"
        }
      ]
      healthCheck = {
        retries     = 10,
        command     = ["CMD-SHELL", "wget -q 'http://127.0.0.1:6070/healthz' -O /dev/null || exit 1"]
        timeout     = 10
        interval    = 30
        startPeriod = null
      }
      environment = [
        { name = "JAEGER_AGENT_HOST", value = "localhost" }, # TODO: this value is wrong
        # Tell this container the hostname of it's service (container pair). For example,
        # indexed-search-1 should would be a single indexed-search service, comprised of both a
        # single search-indexer and indexed-searcher containers. The hostname should be identical
        # for both, used for sharding / automatic rebalancing.
        { name = "HOSTNAME", value = "indexed-search-${each.key}" }
      ]
    }
  ])

  # This placement constraint ensures the container is deployed on the right EC2 instance
  # with this attribute.
  placement_constraints {
    type       = "memberOf"
    expression = "attribute:com.sourcegraph.service == indexed-search-${each.key}"
  }
  volume {
    name      = "data"
    host_path = "/data"
  }
}

resource "aws_ecs_service" "indexed_search" {
  for_each = { for i in range(var.indexed_search_instances) : "${i}" => i }

  name            = "indexed-search-${each.key}"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.indexed_search[each.key].arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.indexed_search[each.key].name
    weight            = 1
  }
}
