output "sg_ids" {
  value = {
    for sg_list, sg in aws_security_group.rules :
    sg_list => sg.id
  }
}