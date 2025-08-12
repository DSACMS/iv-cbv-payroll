resource "aws_ecs_service" "solid_queue" {
  name                   = "${var.service_name}-solid_queue"
  cluster                = aws_ecs_cluster.cluster.arn
  launch_type            = "FARGATE"
  task_definition        = aws_ecs_task_definition.solid_queue.arn
  desired_count          = var.solidqueue_desired_instance_count
  enable_execute_command = var.enable_command_execution ? true : null

  network_configuration {
    assign_public_ip = false
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.app.id] # Or another SG if needed
  }

  # TODO: you should enable rollback when ready to go to prod.
  deployment_circuit_breaker {
    enable   = true
    rollback = false
  }

}



resource "aws_ecs_task_definition" "solid_queue" {
  family             = var.service_name
  execution_role_arn = aws_iam_role.task_executor.arn
  task_role_arn      = aws_iam_role.app_service.arn

  container_definitions = jsonencode([
    {
      name        = local.container_name,
      image       = local.image_url,
      memory      = var.memory,
      cpu         = var.cpu,
      networkMode = "awsvpc",
      essential   = true,
      command     = ["bin/rails", "solid_queue:start"],
      # TODO: Reenable readonlyRootFilesystem when we can have it behave
      # consistently in dev (demo) and production.
      # readonlyRootFilesystem = !var.enable_command_execution,
      readonlyRootFilesystem = false,

      # Need to define all parameters in the healthCheck block even if we want
      # to use AWS's defaults, otherwise the terraform plan will show a diff
      # that will force a replacement of the task definition
      healthCheck = {
        interval = 30,
        retries  = 3,
        timeout  = 5,
        command = ["CMD-SHELL",
          "bin/solidqueue-health-check.sh"
        ]
      },
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
