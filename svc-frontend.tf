resource "aws_ecs_task_definition" "frontend" {
  family = "${var.cluster_name}-frontend"
  container_definitions = jsonencode([
    {
      requiresCompatibilities = "EC2"
      name                    = "frontend"
      image                   = "${local.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/sourcegraph-frontend:3.41.0"
      cpu                     = 4096 # 4 CPUs
      memory                  = 8192 # 8 GiB
      essential               = true
      portMappings = [
        {
          hostPort      = 3080,
          protocol      = "tcp",
          containerPort = 3080
        },
        {
          hostPort      = 3443,
          protocol      = "tcp",
          containerPort = 3443
        },
        {
          hostPort      = 3090,
          protocol      = "tcp",
          containerPort = 3090
        },
        {
          hostPort      = 6060,
          protocol      = "tcp",
          containerPort = 6060
        }
      ]
      environment = [
        { name = "DEPLOY_TYPE", value = "pure-docker" },
        # TODO: every vaue below here is wrong
        { name = "JAEGER_AGENT_HOST", value = "localhost" },                                                          # TODO: this value is wrong
        { name = "PGHOST", value = "pgsql" },                                                                         # TODO
        { name = "CODEINTEL_PGHOST", value = "codeintel-db" },                                                        # TODO
        { name = "CODEINSIGHTS_PGDATASOURCE", value = "postgres://postgres:password@codeinsights-db:5432/postgres" }, # TODO
        { name = "SRC_SYNTECT_SERVER", value = "http://syntect-server:9238" },                                        # TODO
        { name = "SRC_GIT_SERVERS", value = "gitserver-1:3178 gitserver-2:3178" },                                    # TODO
        { name = "SEARCHER_URL", value = "searcher-1:3181 searcher-2:3181" },                                         # TODO
        { name = "SYMBOLS_URL", value = "symbols-1:3184 symbols-2:3184" },                                            # TODO
        { name = "INDEXED_SEARCH_SERVERS", value = "indexed-search-1:6070 indexed-search-2:6070" },                   # TODO
        { name = "SRC_FRONTEND_INTERNAL", value = "sourcegraph-frontend-internal:3090" },                             # TODO
        { name = "REPO_UPDATER_URL", value = "http://repo-updater:3182" },                                            # TODO
        { name = "GRAFANA_SERVER_URL", value = "http://grafana:3370" },                                               # TODO
        { name = "JAEGER_SERVER_URL", value = "http://jaeger:16686" },                                                # TODO
        { name = "GITHUB_BASE_URL", value = "http://github-proxy:3180" },                                             # TODO
        { name = "PROMETHEUS_URL", value = "http://prometheus:9090" },                                                # TODO
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
        retries     = 5,
        command     = ["CMD-SHELL", "wget -q 'http://127.0.0.1:3080/healthz' -O /dev/null || exit 1"]
        timeout     = 10
        interval    = 5
        startPeriod = 5
      }
    }
  ])
  network_mode = "awsvpc"
}

resource "aws_ecs_service" "frontend" {
  name            = "frontend"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.frontend.arn
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
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 3080
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_internal.arn
    container_name   = "frontend"
    container_port   = 3090
  }
}

resource "aws_lb_target_group" "frontend" {
  name                          = "${var.cluster_name}-frontend"
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

resource "aws_lb_target_group" "frontend_internal" {
  name                          = "${var.cluster_name}-frontend-internal"
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

resource "aws_lb" "frontend" {
  name                       = "${var.cluster_name}-frontend"
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

resource "aws_lb" "frontend_internal" {
  name                       = "${var.cluster_name}-frontend-internal"
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

resource "aws_alb_listener" "frontend" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.frontend.id
    type             = "forward"
  }
}

resource "aws_alb_listener" "frontend_internal" {
  load_balancer_arn = aws_lb.frontend_internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.frontend_internal.id
    type             = "forward"
  }
}
