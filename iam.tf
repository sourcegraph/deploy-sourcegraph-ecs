# AWS IAM roles needed to perform task execution and task management.

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.prefix}-ecs-task-execution-role"

  # Role policy from https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
