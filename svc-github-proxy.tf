resource "aws_ecs_task_definition" "github_proxy" {
  family = "${var.cluster_name}-github-proxy"
  container_definitions = jsonencode([
    {
      requiresCompatibilities = "EC2"
      name                    = "github-proxy"
      image                   = "${local.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/sourcegraph-github-proxy:3.41.0"
      cpu                     = 1024 # 1 CPUs
      memory                  = 1024 # 1 GiB
      essential               = true
      portMappings = [
        {
          hostPort      = 3180,
          protocol      = "tcp",
          containerPort = 3180
        },
        {
          hostPort      = 6060,
          protocol      = "tcp",
          containerPort = 6060
        }
      ]
      environment = [
        { name = "SRC_FRONTEND_INTERNAL", value = aws_lb.frontend_internal.dns_name },
        { name = "JAEGER_AGENT_HOST", value = "localhost" }, # TODO: this value is wrong
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
      # TODO: github-proxy has no health check endpoint.
      # healthCheck = {
      #   retries     = 3,
      #   command     = ["CMD-SHELL", "wget -q 'http://127.0.0.1:3180/health' -O /dev/null || exit 1"]
      #   timeout     = 5
      #   interval    = 5
      #   startPeriod = 5
      # }
    }
  ])
  network_mode = "awsvpc"
}

resource "aws_ecs_service" "github_proxy" {
  name            = "github-proxy"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.github_proxy.arn
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
    target_group_arn = aws_lb_target_group.github_proxy.arn
    container_name   = "github-proxy"
    container_port   = 3180
  }
}

resource "aws_lb_target_group" "github_proxy" {
  name                          = "${var.cluster_name}-github-proxy"
  target_type                   = "ip"
  port                          = 80
  protocol                      = "HTTP"
  vpc_id                        = module.ecs_vpc.vpc_id
  load_balancing_algorithm_type = "round_robin"
  slow_start                    = 0
  # TODO: github-proxy has no health check endpoint.
  # health_check {
  #   protocol            = "HTTP"
  #   path                = "/health"
  #   matcher             = "200"
  #   interval            = "30"
  #   timeout             = "3"
  #   healthy_threshold   = "2" // successful requests
  #   unhealthy_threshold = "2" // failed requests
  # }
}

resource "aws_lb" "github_proxy" {
  name                       = "${var.cluster_name}-github-proxy"
  internal                   = true # private subnet access only
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

resource "aws_alb_listener" "github_proxy" {
  load_balancer_arn = aws_lb.github_proxy.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.github_proxy.id
    type             = "forward"
  }
}
