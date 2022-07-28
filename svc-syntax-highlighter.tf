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
      logConfiguration = {
        logDriver     = "awslogs"
        secretOptions = null
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.primary.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = var.cluster_name
        }
      }
      healthCheck = {
        retries     = 3,
        command     = ["CMD-SHELL", "wget -q 'http://127.0.0.1:9238/health' -O /dev/null || exit 1"]
        timeout     = 5
        interval    = 5
        startPeriod = 5
      }
    }
  ])
  network_mode = "awsvpc"
}

resource "aws_ecs_service" "syntax_highlighter" {
  name            = "syntax-highlighter"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.syntax_highlighter.arn
  desired_count   = 2
  network_configuration {
    subnets         = module.ecs_vpc.private_subnets
    security_groups = [module.ec2_security_group.security_group_id]
  }

  capacity_provider_strategy {
    capacity_provider = module.general_cluster_nodes.capacity_provider_name
    weight            = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.syntax_highlighter.arn
    container_name   = "syntax-highlighter"
    container_port   = 9238
  }
}

resource "aws_lb_target_group" "syntax_highlighter" {
  name                          = "${var.cluster_name}-syntax-highlighter"
  target_type                   = "ip"
  port                          = 80
  protocol                      = "HTTP"
  vpc_id                        = module.ecs_vpc.vpc_id
  load_balancing_algorithm_type = "round_robin"
  slow_start                    = 0
  health_check {
    protocol            = "HTTP"
    path                = "/health"
    matcher             = "200"
    interval            = "30"
    timeout             = "3"
    healthy_threshold   = "2" // successful requests
    unhealthy_threshold = "2" // failed requests
  }
}

resource "aws_lb" "syntax_highlighter" {
  name                       = "${var.cluster_name}-syntax-highlighter"
  internal                   = false # private subnet access only
  load_balancer_type         = "application"
  security_groups            = [module.allow_all.security_group_id]
  subnets                    = module.ecs_vpc.public_subnets
  idle_timeout               = 300 # 5 minutes
  enable_deletion_protection = false

  # TODO: standard tags
  # tags = {
  #   Environment = "production"
  # }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_lb.syntax_highlighter.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.syntax_highlighter.id
    type             = "forward"
  }
}
