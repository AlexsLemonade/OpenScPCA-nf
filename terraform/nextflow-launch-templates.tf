resource "aws_launch_template" "nf_lt_standard" {
  name = "openscpca-nf-standard"
  # the AMI used is the Amazon ECS-optimized Amazon Linux 2023 AMI
  # id determined with `aws ssm get-parameters --names /aws/service/ecs/optimized-ami/amazon-linux-2023/recommended --region us-east-2`
  image_id = "ami-097abe41711c05939"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 128 #GiB
      volume_type           = "gp3"
      encrypted             = true
      km_key_id            = "arn:aws:km:us-east-2:992382809252:key/851995f3-26b6-48c1-9d61-c32dd7a8ee83"
      delete_on_termination = true
    }
  }
  update_default_version = true
}
