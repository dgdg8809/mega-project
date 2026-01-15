data "aws_availability_zones" "zones" {
}

locals {
  az_list = slice(data.aws_availability_zones.zones.names, 0, var.az_count)
}

resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = "${var.region_name}-vpc-main"
  }
}
resource "aws_subnet" "publics" {
  count = var.public_subnet_count
  vpc_id = aws_vpc.main.id
  cidr_block = cidrsubnet(var.cidr_block, var.subnet_bits, count.index)
  availability_zone = local.az_list[count.index % var.az_count]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.region_name}-public-subnet-${count.index + 1 }"
  }
}


resource "aws_subnet" "privates" {
  count = var.private_subnet_count

  vpc_id = aws_vpc.main.id
  cidr_block = cidrsubnet(var.cidr_block, var.subnet_bits, pow(2, var.subnet_bits -1 ) + count.index)
  availability_zone = local.az_list[count.index % var.az_count]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.region_name}-private-subnet-${count.index + 1 }"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.region_name}-vpc-igw"
  } 
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id
    route  {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "${var.region_name}-vpc-route-public"

    }

}

resource "aws_route_table" "privates" {
    count = var.private_subnet_count
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "${var.region_name}-vpc-route-private-${count.index + 1}" 

    }
}

resource "aws_route_table_association" "publics" {
  count = var.public_subnet_count
  route_table_id = aws_route_table.public.id
  subnet_id = aws_subnet.publics[count.index].id
  
}

resource "aws_route_table_association" "privates" {
  count = var.private_subnet_count
  route_table_id = aws_route_table.privates[count.index].id
  subnet_id = aws_subnet.privates[count.index].id
  
}

# resource "aws_eip" "nat" {
#   count  = var.enable_nat_gateway ? 1 : 0
#   domain = "vpc"

#   tags = {
#     Name = "${var.region_name}-nat-eip"
#   }
# }

# resource "aws_nat_gateway" "nat" {
#   count         = var.enable_nat_gateway ? 1 : 0
#   allocation_id = aws_eip.nat[0].id
#   subnet_id     = aws_subnet.publics[0].id  

#   depends_on = [aws_internet_gateway.igw]

#   tags = {
#     Name = "${var.region_name}-nat"
#   }
# }


# resource "aws_route" "private_default_via_nat" {
#   count                  = var.enable_nat_gateway ? var.private_subnet_count : 0
#   route_table_id         = aws_route_table.privates[count.index].id
#   destination_cidr_block = "0.0.0.0/0"
#   nat_gateway_id         = aws_nat_gateway.nat[0].id
# }
