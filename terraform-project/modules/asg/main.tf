resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-lt-"
  image_id      = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name


  user_data = base64encode(var.user_data)

  network_interfaces {
    associate_public_ip_address = var.associate_public_ip_address
    security_groups             = [var.security_group_id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.name
    }
  }
}

resource "aws_autoscaling_group" "this" {
  name                = var.name
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = var.subnet_ids

  target_group_arns = var.target_group_arns
  health_check_type = "ELB"
  health_check_grace_period = 1000


  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = true
  }
}
