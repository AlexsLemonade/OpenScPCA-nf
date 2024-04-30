# VPC and network security settings

resource "aws_security_group" "nf_security" {
  name = "openscpca-nf-security-group"
  # use the workload vpc
  vpc_id = "vpc-04fd1c970b958aa23"

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
