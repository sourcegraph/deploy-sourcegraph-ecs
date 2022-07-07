resource "aws_ecs_task_definition" "syntax_highlighter" {
  family = "${var.prefix}-syntax-highlighter"
  container_definitions = jsonencode([
    {
      requiresCompatibilities = "EC2"
      name                    = "syntax-highlighter"
      image                   = "index.docker.io/sourcegraph/syntax-highlighter:3.41.0@sha256:c39677af141613aecd733663b60585e85a17e3f8a44e02bd864e6a6954e7aba1"
      cpu                     = 4
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
    }
  ])

  volume {
    name      = "service-storage"
    host_path = "/ecs/service-storage"
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-east-1a, us-east-1b]"
  }
}

resource "aws_ecs_service" "syntax_highlighter" {
  name            = "syntax-highlighter"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.syntax_highlighter.arn
  desired_count   = 2

  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-east-1a, us-east-1b]"
  }
}
