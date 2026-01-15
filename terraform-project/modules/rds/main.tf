resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.identifier}-subnet-group"
  }
}

resource "aws_db_instance" "this" {
  identifier = var.identifier

  engine         = var.engine
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.username
  password = var.password

  allocated_storage = var.allocated_storage

  vpc_security_group_ids = [var.security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.this.name

  skip_final_snapshot = true
  publicly_accessible = false

  backup_retention_period = 0

  tags = {
    Name = var.identifier
  }
}
