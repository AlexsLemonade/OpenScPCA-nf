resource "aws_launch_template" "nf_lt_standard" {
  name = "openscpca-nf-standard"
  # the AMI used is the Amazon ECS-optimized Amazon Linux 2023 AMI
  # id determined with `aws ssm get-parameters --names /aws/service/ecs/optimized-ami/amazon-linux-2023/recommended --region us-east-2`
  image_id = "ami-06adbea8e9d7cae16"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 128 #GiB
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }
  update_default_version = true
}
