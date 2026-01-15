output "vpc_id" {
    value = aws_vpc.main.id
}

output "az_list" {
    value = local.az_list
}

output "public_subnet_ids" {
    value = [
        for subnet in aws_subnet.publics : subnet.id
    ]
}

output "private_subnet_ids" {
    value = [
        for subnet in aws_subnet.privates : subnet.id
    ]
}