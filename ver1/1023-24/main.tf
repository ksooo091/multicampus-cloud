data "http" "ipinfo" {
  url = "https://ipinfo.io"
}

// vpc name = lab-vpc




/////// VPC ///////

resource "aws_vpc" "lab-vpc" {

  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "lab-vpc"

  }
}



resource "aws_subnet" "public-subnet-2a" {
  vpc_id            = aws_vpc.lab-vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "lab-public-subnet-2a"
  }
}

resource "aws_subnet" "public-subnet-2c" {
  vpc_id            = aws_vpc.lab-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "lab-public-subnet-2c"
  }
}

resource "aws_subnet" "private-subent-2a" {
  vpc_id            = aws_vpc.lab-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "lab-private-subent-2a"
  }
}

resource "aws_subnet" "private-subnet-2c" {
  vpc_id            = aws_vpc.lab-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "lab-private-subent-2c"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.lab-vpc.id

  tags = {
    Name = "lab-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "lab-igw-rt"
  }
}


resource "aws_route_table_association" "public-a" {
  subnet_id      = aws_subnet.public-subnet-2a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public-c" {
  subnet_id      = aws_subnet.public-subnet-2c.id
  route_table_id = aws_route_table.public.id
}









//////// EC2 /////////


resource "aws_instance" "web" {

  ami                         = data.aws_ami.al-recent.id
  instance_type               = "t3.micro"
  key_name                    = var.keypair
  subnet_id                   = aws_subnet.public-subnet-2c.id
  associate_public_ip_address = true

  tags = {
    Name = "Amazon Linux 2 Web Server"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }
  vpc_security_group_ids = [aws_security_group.web-server.id]
  
user_data = <<EOF
#!/bin/bash
sleep 15
yum update -y
yum install httpd -y
systemctl enable httpd
systemctl start httpd
echo '<html><h1>Hello From Your Web Server!</h1></html>' > /var/www/html/index.html
EOF
monitoring = true
disable_api_termination = true

root_block_device {
  volume_size = 10
}

}



resource "aws_security_group" "web-server" {
  name        = "web-sg"
  description = "Allow HTTP, SSH"
  vpc_id      = aws_vpc.lab-vpc.id

  dynamic "ingress" {
    for_each = {
      80 = { protocol = "tcp", cidr = "0.0.0.0/0" }
      22 = { protocol = "tcp", cidr = format("%s/32", jsondecode(data.http.ipinfo.response_body).ip)}

    }
    content {
      cidr_blocks = [ingress.value.cidr]
      from_port   = ingress.key
      to_port     = ingress.key
      protocol    = ingress.value.protocol
      description = ingress.value.protocol
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

output "web-publicip" {
  value = aws_instance.web.public_ip
}

data "aws_ami" "al-recent" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-20*-x86_64"]
  }
owners = ["137112412989"] 
}