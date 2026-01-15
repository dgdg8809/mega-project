locals {
   ec2_list = merge([
    for k, v in var.ec2_instances : {
      for i in range(v.count) : "${k}-${i + 1}" => merge(v,
      {subnet = v.public ? var.public_subnet_ids[i % length(var.public_subnet_ids)] : var.private_subnet_ids[i % length(var.private_subnet_ids)] })
    }
  ]...)
}

resource "aws_instance" "ec2s" {
  for_each = local.ec2_list

  ami           = each.value.ami
  instance_type = each.value.instance_type
  subnet_id = each.value.subnet
  vpc_security_group_ids = [var.sg_ids[each.value.sg_name]]
  key_name      = var.key_name
  user_data_base64 = each.value.user_data
  tags = {
    Name = "${var.region_name}-ec2-${each.key}"
  }

}



