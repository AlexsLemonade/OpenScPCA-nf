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
      kms_key_id            = aws_kms_key.nf_work_key.arn
      delete_on_termination = true
    }
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags = "enabled"
  }
  update_default_version = true
}
