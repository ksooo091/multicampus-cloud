data "aws_iam_policy_document" "ecs_task_execution" {
  version = "2012-10-17"
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}




resource "aws_iam_role" "ecs" {
  name               = "ecs-study"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_ecs_cluster" "ecs-cluster" {
  name = "ecs-cluster"
}



resource "aws_ecs_task_definition" "app" {
  family                   = "app"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs.arn
  cpu                      = 512
  memory                   = 1024
  requires_compatibilities = ["FARGATE"]
  container_definitions = templatefile("${path.module}/task.tamplate", {
    aws_ecr_repository = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-2.amazonaws.com/app",
    tag                = "latest",
    container_port     = "8080",
    host_port          = "8080",
    app_name           = "app"
  })

}




resource "aws_ecs_service" "app" {
  name                 = "app"
  cluster              = aws_ecs_cluster.ecs-cluster.id
  task_definition      = aws_ecs_task_definition.app.arn
  desired_count        = 2
  force_new_deployment = true
  launch_type          = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.was.id]
    subnets         = [aws_subnet.private[2].id,aws_subnet.private[3].id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.was-alb-8080.arn
    container_name   = "app"
    container_port   = 8080
  }


}







resource "aws_ecs_task_definition" "job" {
  family                   = "job"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs.arn
  cpu                      = 512
  memory                   = 1024
  requires_compatibilities = ["FARGATE"]
  container_definitions = templatefile("${path.module}/task.tamplate", {
    aws_ecr_repository = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-2.amazonaws.com/job",
    tag                = "latest",
    container_port     = "8888",
    host_port          = "8888",
    app_name           = "job"
  })

}





resource "aws_ecs_service" "job" {
  name                 = "job"
  cluster              = aws_ecs_cluster.ecs-cluster.id
  task_definition      = aws_ecs_task_definition.job.arn
  desired_count        = 2
  force_new_deployment = true
  launch_type          = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.was.id]
    subnets         = [aws_subnet.private[2].id,aws_subnet.private[3].id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.was-alb-8888.arn
    container_name   = "job"
    container_port   = 8888
  }


}













resource "aws_ecs_task_definition" "web" {
  family                   = "web"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs.arn
  cpu                      = 512
  memory                   = 1024
  requires_compatibilities = ["FARGATE"]
  container_definitions = templatefile("${path.module}/task.tamplate", {
    aws_ecr_repository = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-2.amazonaws.com/front",
    tag                = "latest",
    container_port     = "80",
    host_port          = "80",
    app_name           = "web"
  })
  lifecycle {
    ignore_changes = [container_definitions]
  }
}





resource "aws_ecs_service" "web" {
  name                 = "web"
  cluster              = aws_ecs_cluster.ecs-cluster.id
  task_definition      = aws_ecs_task_definition.web.arn
  desired_count        = 2
  force_new_deployment = true
  launch_type          = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.web.id]
    subnets         = [aws_subnet.private[0].id, aws_subnet.private[1].id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web-alb.arn
    container_name   = "web"
    container_port   = 80
  }
  lifecycle {
    ignore_changes = [desired_count]
  }

}

////// auto scail

resource "aws_iam_role" "ecs_autoscale" {
  name = "testproject-ecs-autoscale-iam-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Autoscaling",
      "Effect": "Allow",
      "Principal": {
        "Service": "application-autoscaling.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_autoscale" {
  role = aws_iam_role.ecs_autoscale.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}

resource "aws_appautoscaling_target" "ecs_target" {
  min_capacity = 2
  max_capacity = 4
  resource_id =  "service/${aws_ecs_cluster.ecs-cluster.name}/${aws_ecs_service.web.name}" 
  role_arn = aws_iam_role.ecs_autoscale.arn
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"

}

resource "aws_appautoscaling_policy" "ecs_policy_scale_out" {
  name = "scale-out"
  policy_type = "StepScaling"
  resource_id = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace = aws_appautoscaling_target.ecs_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type = "PercentChangeInCapacity"
    cooldown = 1
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = 1
    }
  }
}


resource "aws_cloudwatch_metric_alarm" "cpu_alert" {
  alarm_name                = "testproject-cpu-alert"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  threshold                 = "70"
  datapoints_to_alarm       = "2"
  insufficient_data_actions = []
  alarm_actions             = [aws_appautoscaling_policy.ecs_policy_scale_out.arn]

  metric_query {
    id          = "cpualert"
    expression  = "mm1m0 * 100 / mm0m0"
    return_data = "true"
  }

  metric_query {
    id = "mm1m0"

    metric {
      metric_name = "CpuUtilized"
      namespace   = "ECS/ContainerInsights"
      period      = "30"
      stat        = "Sum"

      dimensions = {
        ClusterName = aws_ecs_cluster.ecs-cluster.name
        ServiceName = aws_ecs_service.web.name
      }
    }
  }

  metric_query {
    id = "mm0m0"

    metric {
      metric_name = "CpuReserved"
      namespace   = "ECS/ContainerInsights"
      period      = "30"
      stat        = "Sum"

      dimensions = {
        ClusterName = aws_ecs_cluster.ecs-cluster.name
        ServiceName = aws_ecs_service.web.name
      }
    }
  }
}