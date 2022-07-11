# AWS IAM roles

# ECS task execution role
# Used for executing ECS tasks.
resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.cluster_name}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution.json
}
data "aws_iam_policy_document" "ecs_task_execution" {
  # Role policy from https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
  version = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# ECS/EC2 Container Service agent role.
# Used for launching EC2 instances, registering them into the ECS cluster, etc.
resource "aws_iam_role" "ecs_agent" {
  name               = "${var.cluster_name}-ecs-agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
}
data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
resource "aws_iam_instance_profile" "ecs_agent" {
  name = "${var.cluster_name}-ecs-agent"
  role = aws_iam_role.ecs_agent.name
}
