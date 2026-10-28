resource "aws_db_parameter_group" "mysql" {
  name   = "app-db-mysql8"
  family = "mysql8.0"

  parameter {
    name  = "time_zone"
    value = "Brazil/East"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = var.rds_long_query_time
  }

  parameter {
    name  = "log_output"
    value = "FILE"
  }
}

resource "aws_db_instance" "instance_db" {
  identifier        = "app-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t4g.micro"
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.db.name
  parameter_group_name   = aws_db_parameter_group.mysql.name
  apply_immediately      = true
  vpc_security_group_ids = [aws_security_group.db.id]

  publicly_accessible = false
  multi_az            = false
  skip_final_snapshot = true
  deletion_protection = false

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]
  depends_on                      = [aws_cloudwatch_log_group.rds]

  backup_retention_period = 7
  backup_window           = "03:00-04:00"

  tags = {
    Name = "app-db"
  }
}