resource "aws_vpc" "main" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true 
    enable_dns_support = true

    tags = merge{
        var.tags,
        {
            Name = "${var.name_prefix}-nat-${count.index + 1}"
        }

    }
    depends_on = [aws_internet_gateway.main]
}

resource "aws_internet_gateway" "main" {
    vpc.id = aws_vpc.main.id

    tags = merge{
        var.tags,
        {
            Name = "${var.name_prefix}-igw"
        }
    }
}

resource "aws_subnet" "public" {
    count = length(var.public_subnet)
    vpc_id = aws_main.vpc.id
    cidr_block = var.public_subnet[count.index]
    availability_zone = var.azs[count.index]
    map_public_ip_on_launch = true 

    tags = merge{
        var.tags,
        var.public_subnet_tags,
        {
            Name = "${var.name_prefix}-public-$[var.azs[count.index]}"
            Type = "public"
        }
    }
}

resource "aws_subnet" "private" {
    count = length(var.private_subnet)
    vpc_id = aws_vpc.main.id
    cidr_block = var.private_subnet[count.index]
    availability_zone = var.azs[count.index]
    

    tags = merge {
        var.tags,
        var.private_subnet_tags,
        {
            Name = "${var.name_prefix}-private-${var.azs[count.index]}"
            Type = "private"
        }
    }
}

resource "aws eip " "nat" {
    count = var.enable_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0 
    domain = "vpc"

    tags = merge{
        var.tags,
        {
            Name = "{var.name_prefix}-nat-eip${count.index + 1}"

        }
    }
    depends_on = [aws_internet_gateway.main]
}

resource " aws_nat_gateway" "main"{
    count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
    allocation_id = aws_eip.nat[count.index].id

    tags = merge{
        var.tags,
        {
            Name = "${var.name_prefix}-nat-${count.index + 1}"
        }
    }
    depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id

    tags = merge{
        var.tags,
        {
            Name = "${var.name_prefix}-public-rt"
        }
    }
}

resource "aws_route" "public_internet_gateway" {
    route_table_id = aws_route_table.public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
    count = length(var.public.subnets)
    subnet_id = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private"{
    count = var.single_nat_gateway ? 1 : length(var.private_subnets)
    vpc_id = aws_vpc.main.id

    tags = merge {
        var.tags,
        {
            Name = "${var.name-prefix}-private-rt-${count.index + 1}"
        }
    }
}

resource "aws_route" "private_nat_gateway" {
    count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnets)) : 0
    route_table_id = aws_route_table.private[count.index].id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id 
}

resource " aws_route_table_association "private"{
    count = length(var.private_subnets)
    subnet_id = aws_subnet.private[count.index].id
    route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id 
}