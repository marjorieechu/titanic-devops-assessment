resource "aws_db_subnet_group" "this" {
  name        = format("%s-%s-db-subnet", var.tags["environment"], var.tags["project"])
  description = "Database subnet group for ${var.tags["project"]}"
  subnet_ids  = var.subnet_ids

  tags = var.tags
}

resource "aws_security_group" "rds" {
  name        = format("%s-%s-rds-sg", var.tags["environment"], var.tags["project"])
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "db_password" {
  name        = format("%s-%s-db-password", var.tags["environment"], var.tags["project"])
  description = "RDS database password for ${var.tags["project"]}"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.config.db_username
    password = random_password.db_password.result
    engine   = var.config.engine
    host     = aws_db_instance.this.endpoint
    port     = 5432
    dbname   = var.config.db_name
  })
}

resource "aws_db_instance" "this" {
  identifier = format("%s-%s-db", var.tags["environment"], var.tags["project"])

  engine               = var.config.engine
  engine_version       = var.config.engine_version
  instance_class       = var.config.instance_class
  allocated_storage    = var.config.allocated_storage
  max_allocated_storage = var.config.max_allocated_storage

  db_name  = var.config.db_name
  username = var.config.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az                = var.config.multi_az
  backup_retention_period = var.config.backup_retention_period
  deletion_protection     = var.config.deletion_protection

  storage_encrypted = true
  skip_final_snapshot = var.tags["environment"] != "prod"

  tags = var.tags
}
