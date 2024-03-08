# VPC and network security settings

resource "aws_security_group" "nf_security" {
  name   = "openscpca-nf-security-group"
  vpc_id = aws_vpc.nf_vpc.id
  tags   = var.default_tags

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
  tags = merge(
    {
      Name = "openscpca-nf-vpc"
    },
    var.default_tags
  )
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "nf_gateway" {
  vpc_id = aws_vpc.nf_vpc.id

  tags = merge(
    {
      Name = "openscpca-nf-gateway"
    },
    var.default_tags
  )

}

resource "aws_subnet" "nf_subnet" {
  vpc_id     = aws_vpc.nf_vpc.id
  cidr_block = "10.1.1.0/24"
  tags = merge(
    {
      Name = "opesnscpca-nextflow-subnet"
    },
    var.default_tags
  )
  map_public_ip_on_launch = true
}

resource "aws_route_table" "nf_route_table" {
  vpc_id = aws_vpc.nf_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nf_gateway.id
  }

  tags = merge(
    {
      Name = "openscpca-nf-route-table"
    },
    var.default_tags
  )
}

resource "aws_route_table_association" "nf_route_table_association" {
  subnet_id      = aws_subnet.nf_subnet.id
  route_table_id = aws_route_table.nf_route_table.id
}
