terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
    DB_STRING  = ""
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
    cidr_blocks = ["213.32.243.91/32"] # Adjust this to restrict access
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


## ECS 
