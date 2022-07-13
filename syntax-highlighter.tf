resource "aws_ecs_task_definition" "syntax_highlighter" {
  family = "${var.cluster_name}-syntax-highlighter"
  container_definitions = jsonencode([
    {
      requiresCompatibilities = "EC2"
      name                    = "syntax-highlighter"
      image                   = "${local.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/sourcegraph-syntax-highlighter:3.41.0"
      cpu                     = 4096 # 4 CPUs
      memory                  = 6144 # 6 GiB
      essential               = true
      portMappings = [
        {
          hostPort      = 9238,
          protocol      = "tcp",
          containerPort = 9238
        },
        {
          hostPort      = 6060,
          protocol      = "tcp",
          containerPort = 6060
        }
      ]
      healthCheck = {
        retries     = 3,
        command     = ["CMD-SHELL", "wget -q 'http://127.0.0.1:9238/health' -O /dev/null || exit 1"]
        timeout     = 5
        interval    = 5
        startPeriod = 5
      }
    }
  ])

  # TODO: add NLB
  # load_balancer {
  #   target_group_arn = aws_lb_target_group.foo.arn
  #   container_name   = "mongo"
  #   container_port   = 8080
  # }

  # TODO: figure out multi-AZ deployment strategy
  # placement_constraints {
  #   type       = "memberOf"
  #   expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  # }
}

resource "aws_ecs_service" "syntax_highlighter" {
  name            = "syntax-highlighter"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.syntax_highlighter.arn
  desired_count   = 2

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.capacity_provider.name
    weight            = 1
  }
}
