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
