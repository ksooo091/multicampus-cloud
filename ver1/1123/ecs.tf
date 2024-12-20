data "aws_iam_policy_document" "ecs_task_execution_role" {
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
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_ecs_cluster" "jobapp" {
  name = "jobapp"
}


# data "template_file" "app" {
#   template = file("${path.module}/task.tpl")

#   vars = {
#     aws_ecr_repository = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-2.amazonaws.com/app"
#     tag                = "1"
#     container_port     = "8080"
#     host_port          = "8080"
#     app_name           = "app"

#   }
# }


resource "aws_ecs_task_definition" "app" {
  family                   = "app"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs.arn
  cpu                      = 512
  memory                   = 1024
  requires_compatibilities = ["FARGATE"]
  container_definitions = templatefile("${path.module}/task.tamplate", {
    aws_ecr_repository = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-2.amazonaws.com/app",
    tag                = "2",
    container_port     = "8080",
    host_port          = "8080",
    app_name           = "app"
  })

}


resource "aws_security_group" "was8080" {
  name        = "was8080-sg"
  description = "was sg"
  vpc_id      = aws_vpc.vpc.id



  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.was-alb.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WAS8080-SG"
  }
}



resource "aws_ecs_service" "app" {
  name                 = "app"
  cluster              = aws_ecs_cluster.jobapp.id
  task_definition      = aws_ecs_task_definition.app.arn
  desired_count        = 2
  force_new_deployment = true
  launch_type          = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.was8080.id]
    subnets         = aws_subnet.was[*].id
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
    tag                = "3",
    container_port     = "8888",
    host_port          = "8888",
    app_name           = "job"
  })

}


resource "aws_security_group" "was8888" {
  name        = "was8888-sg"
  description = "was sg"
  vpc_id      = aws_vpc.vpc.id



  ingress {
    from_port       = 8888
    to_port         = 8888
    protocol        = "tcp"
    security_groups = [aws_security_group.was-alb.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WAS8888-SG"
  }
}



resource "aws_ecs_service" "job" {
  name                 = "job"
  cluster              = aws_ecs_cluster.jobapp.id
  task_definition      = aws_ecs_task_definition.job.arn
  desired_count        = 2
  force_new_deployment = true
  launch_type          = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.was8888.id]
    subnets         = aws_subnet.was[*].id
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
    aws_ecr_repository = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-2.amazonaws.com/web",
    tag                = "1",
    container_port     = "80",
    host_port          = "80",
    app_name           = "web"
  })

}


resource "aws_security_group" "web" {
  name        = "web-con-sg"
  description = "was sg"
  vpc_id      = aws_vpc.vpc.id



  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web-alb.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "webcon-SG"
  }
}



resource "aws_ecs_service" "web" {
  name                 = "web"
  cluster              = aws_ecs_cluster.jobapp.id
  task_definition      = aws_ecs_task_definition.web.arn
  desired_count        = 2
  force_new_deployment = true
  launch_type          = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.web.id]
    subnets         = aws_subnet.web[*].id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web-alb.arn
    container_name   = "web"
    container_port   = 80
  }


}
