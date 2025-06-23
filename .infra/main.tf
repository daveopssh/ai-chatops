terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = "us-east-2"
  profile = "personal"
  default_tags {
    tags = local.tags
  }
}

locals {
  myip = "213.32.243.91/32"
  tags = {
    Terraform   = "true"
    Environment = "demo"
  }

}

## ECR 
resource "aws_ecr_repository" "this" {
  name = "davebot"

  image_scanning_configuration {
    scan_on_push = true
  }

}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 1 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 1
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

## Secret Manager
resource "aws_secretsmanager_secret" "this" {
  name                    = "davebot"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    OPENAI_KEY = "",
    }
  )
  lifecycle {
    ignore_changes = [secret_string]
  }
}

## VPC 
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "davebot-net"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-2a", "us-east-2b", "us-east-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

resource "aws_security_group" "davebot_db_sg" {
  name        = "davebot-db-sg"
  description = "Security group for DaveBot RDS access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.myip] # Adjust this to restrict access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## RDS 
module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "davebotdb"

  engine            = "postgres"
  engine_version    = "17.5"
  instance_class    = "db.t4g.micro"
  allocated_storage = 10

  db_name  = "vector_db"
  username = "davebotAdmin"
  port     = "5432"

  iam_database_authentication_enabled = false

  vpc_security_group_ids = [aws_security_group.davebot_db_sg.id]

  # DB subnet group
  create_db_subnet_group          = true
  db_subnet_group_use_name_prefix = true
  subnet_ids                      = module.vpc.public_subnets
  publicly_accessible             = true
  # DB parameter group
  create_db_parameter_group = false

  # Database Deletion Protection
  deletion_protection = false
}


resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

data "aws_iam_policy_document" "ecs_task_execution_role_policy" {
  statement {
    actions = [
      "secretsmanager:*",
      #"secretmanager:GetSecretValue",
      #"secretmanager:DescribeSecret",
    ]

    resources = [
      aws_secretsmanager_secret.this.arn,
      module.db.db_instance_master_user_secret_arn
    ]
  }
}

resource "aws_iam_role_policy" "ecs_custom_task_execution_role_policy" {
  name   = "EcsDaveBotTaskExecutionRolePolicy"
  role   = aws_iam_role.ecs_task_execution_role.id
  policy = data.aws_iam_policy_document.ecs_task_execution_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "davebot-alb"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  # Security Group
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = local.myip
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "10.0.0.0/16"
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "ecs"
      }
    }
  }

  target_groups = {
    ecs = {
      name_prefix       = "ia"
      protocol          = "HTTP"
      port              = 8000
      target_type       = "ip"
      create_attachment = false
    }
  }

  tags = local.tags
}

resource "aws_security_group" "davebot_ecs_sg" {
  name        = "davebot-ecs-sg"
  description = "Security group for DaveBot ECS service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [module.alb.security_group_id] # Adjust this to restrict access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "davebot_cluster" {
  name = "davebot-cluster"

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "davebot" {
  name              = "/ecs/davebot"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "davebot_task" {
  family                   = "davebot-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "davebot-container"
      image     = "${aws_ecr_repository.this.repository_url}:amd64"
      cpu       = 256
      memory    = 512
      essential = true

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/davebot"
          awslogs-region        = "us-east-2"
          awslogs-stream-prefix = "ecs"
        }
      }
      
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]
      
      secrets = [
        {
          name  = "OPENAI_KEY"
          valueFrom = aws_secretsmanager_secret.this.arn
        },
        {
          name  = "DB_USER"
          valueFrom = "${module.db.db_instance_master_user_secret_arn}:username::"
        },
        {
          name  = "DB_PASSWORD"
          valueFrom = "${module.db.db_instance_master_user_secret_arn}:password::"
        }
      ]
      environment = [
        {
          name  = "DB_HOST"
          value = module.db.db_instance_address
        }
      ]
    }
  ])
}


resource "aws_ecs_service" "davebot_service" {
  name            = "davebot-ecs-service"
  cluster         = aws_ecs_cluster.davebot_cluster.id
  task_definition = aws_ecs_task_definition.davebot_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.davebot_ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = module.alb.target_groups["ecs"].arn
    container_name   = "davebot-container"
    container_port   = 8000
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy_attachment,
    aws_ecr_repository.this,
    aws_secretsmanager_secret.this,
    module.db,
    module.vpc,
    module.alb
  ]
}



















