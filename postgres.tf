resource "aws_db_instance" "pgsql" {
  allocated_storage               = 20   # GiB
  max_allocated_storage           = 2048 # 2 TiB (incredibly unlikely we'd reach this in practice)
  allow_major_version_upgrade     = true
  auto_minor_version_upgrade      = true
  backup_retention_period         = 15 # days
  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  engine                          = "postgres"
  engine_version                  = "14.2"
  instance_class                  = "db.m5.large"
  monitoring_interval             = 5
  monitoring_role_arn             = aws_iam_role.rds_ehanced_monitoring.arn
  db_name                         = "sourcegraph"
  username                        = "sourcegraph"
  # The Postgres instance is protected by network policies, not a password.
  password               = "sourcegraph"
  storage_encrypted      = true
  storage_type           = "gp2"
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [module.ec2_security_group.security_group_id]
}

resource "aws_iam_role" "rds_ehanced_monitoring" {
  name = "${var.cluster_name}-rds"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"]
}

resource "aws_db_subnet_group" "postgres" {
  name       = "${var.cluster_name}-postgres"
  subnet_ids = module.ecs_vpc.private_subnets
}
