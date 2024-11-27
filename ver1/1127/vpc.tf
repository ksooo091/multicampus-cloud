
/////// VPC ///////


resource "aws_vpc" "vpc" {

  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "vpc"
  }
}



resource "aws_subnet" "public" {
  count             = 2
  availability_zone = local.use_az[count.index]
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index)

  tags = {
    Name = "public-subnet-${local.az_short[count.index]}"
  }
}



resource "aws_subnet" "private" {
  count = 4

  availability_zone = local.use_az[floor(count.index / 2)]
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + 2)

  tags = {
    Name = "web-subnet-${local.az_short[floor(count.index / 2)]}-${count.index}"
  }
}



resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "igw"
  }
}


resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[1].id

  tags = {
    Name = "natgw"
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_eip" "nat_eip" {

  tags = {
    Name = "natgw-eip"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }


  tags = {
    Name = "igw-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id


  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "nat-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table_association" "private" {
  count          = 4
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}