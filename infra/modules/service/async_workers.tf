resource "aws_ecs_service" "worker" {
  # Do not create the worker service in temporary PR environments
  count                  = var.is_temporary ? 0 : 1
  name                   = "${var.service_name}-worker"
  cluster                = aws_ecs_cluster.cluster.arn
  launch_type            = "FARGATE"
  task_definition        = aws_ecs_task_definition.worker.arn
  desired_count          = var.shoryuken_desired_instance_count
  enable_execute_command = var.enable_command_execution ? true : null

  network_configuration {
    assign_public_ip = false
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.app.id] # Or another SG if needed
  }

  # Deployment Circuit Breaker puts a limit on the number of retries that ECS will attempt
  # when launching a task before it gives up.  Without this, ECS could be in an infinite loop on a bad deploy
  # Circuit breaker attempts 3 times by default for a single deployment instance, otherwise it uses formula found at
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-circuit-breaker.html
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}

resource "aws_ecs_task_definition" "worker" {
  family             = "${var.service_name}-worker"
  execution_role_arn = aws_iam_role.task_executor.arn
  task_role_arn      = aws_iam_role.app_service.arn

  container_definitions = jsonencode([
    {
      name        = "${local.container_name}-worker",
      image       = local.image_url,
      memory      = var.memory,
      cpu         = var.cpu,
      networkMode = "awsvpc",
      essential   = true,
      command     = ["bundle", "exec", "shoryuken", "-R", "-C", "config/shoryuken.yml"],

      environment = local.environment_variables,
      secrets     = var.secrets,
      portMappings = [
        {
          containerPort = var.container_port,
          hostPort      = var.container_port,
          protocol      = "tcp"
        }
      ],
      linuxParameters = {
        capabilities = {
          add  = []
          drop = ["ALL"]
        },
        initProcessEnabled = true
      },
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service_logs.name,
          "awslogs-region"        = data.aws_region.current.name,
          "awslogs-stream-prefix" = local.log_stream_prefix
        }
      },
      mountPoints = [
        {
          containerPath = "/rails/tmp",
          sourceVolume  = "${var.service_name}-tmp"
        }
      ]
    }
  ])

  cpu    = var.cpu
  memory = var.memory

  volume {
    name = "${var.service_name}-tmp"
  }

  requires_compatibilities = ["FARGATE"]

  # Reference https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-networking.html
  network_mode = "awsvpc"
}
