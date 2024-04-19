# VPC and network security settings

resource "aws_security_group" "nf_security" {
  name   = "openscpca-nf-security-group"
  vpc_id = aws_vpc.nf_vpc.id

  ingress {
    description = "Allow all traffic from vpc security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ingress {
  #   description = "SSH from anywhere."
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
}

# resource "aws_key_pair" "nf_keypair" {
#   key_name = "nextflow-key"
#   public_key = "PUT_YOUR_PUBLIC_KEY_HERE"
# }

resource "aws_vpc" "nf_vpc" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "openscpca-nf-vpc"
  }
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "nf_gateway" {
  vpc_id = aws_vpc.nf_vpc.id

  tags = {
    Name = "openscpca-nf-gateway"
  }

}

resource "aws_subnet" "nf_subnet" {
  vpc_id     = aws_vpc.nf_vpc.id
  cidr_block = "10.1.1.0/24"
  tags = {
    Name = "opesnscpca-nf-subnet"
  }
  map_public_ip_on_launch = true
}

resource "aws_route_table" "nf_route_table" {
  vpc_id = aws_vpc.nf_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nf_gateway.id
  }

  tags = {
    Name = "openscpca-nf-route-table"
  }
}

resource "aws_route_table_association" "nf_route_table_association" {
  subnet_id      = aws_subnet.nf_subnet.id
  route_table_id = aws_route_table.nf_route_table.id
}
