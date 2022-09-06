# Cluster

resource "aws_ecr_repository" "main" {
  name                 = format("%s-strapi", local.project)
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_cluster" "main" {
  name = local.ecs_cluster_name
  tags = { Name = local.ecs_cluster_name }
}

resource "aws_cloudwatch_log_group" "strapi" {
  name              = local.logs.name
  retention_in_days = var.logs_tasks_retention
}

# IAM
data "aws_iam_policy_document" "task_execution" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "ecsTaskExecutionRole"
  description        = format("Execution role of %s task", local.ecs_task_name)
  assume_role_policy = data.aws_iam_policy_document.task_execution.json
  tags               = { Name = format("%s-execution-task-role", local.project) }
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_ecs_task_definition" "main" {
  family                   = local.ecs_task_name
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_execution.arn
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions = jsonencode([
    {
      name  = local.ecs_task_name
      image = join(":", [aws_ecr_repository.main.repository_url, "3.0"])
      environment = [
        {
          name  = "DATABASE_CLIENT"
          value = "postgres"
        },
        {
          name  = "DATABASE_HOST"
          value = module.aurora_postgresql.cluster_endpoint
        },
        {
          name  = "DATABASE_PORT"
          value = "module.aurora_postgresql.cluster_port"
        },
        {
          name  = "DATABASE_NAME"
          value = module.aurora_postgresql.cluster_database_name
        },
        {
          name  = "DATABASE_USERNAME"
          value = module.aurora_postgresql.cluster_master_username
        },
        {
          name  = "DATABASE_PASSWORD"
          value = module.aurora_postgresql.cluster_master_password
        },
        {
          name  = "DATABASE_SSL"
          value = "false"
        }
      ]
      essential = true
      portMappings = [
        {
          containerPort = local.strapi_container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.logs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = local.ecs_task_name
        }
      }
    }
  ])

  lifecycle {
  }
}

resource "aws_security_group" "service" {

  name = "ECS Service Security group."

  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0             # Allowing any incoming port
    to_port     = 0             # Allowing any outgoing port
    protocol    = "-1"          # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}

## Service
resource "aws_ecs_service" "main" {
  name                   = format("%s-strapi-srv", local.project)
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.main.arn
  launch_type            = "FARGATE"
  desired_count          = 1
  enable_execute_command = var.ecs_enable_execute_command

  load_balancer {
    target_group_arn = module.alb.target_group_arns[0]
    container_name   = aws_ecs_task_definition.main.family
    container_port   = local.strapi_container_port
  }

  network_configuration {
    subnets          = module.vpc.public_subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.service.id]
  }

}