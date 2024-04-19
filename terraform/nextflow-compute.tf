# This file creates the compute environments used by the default and priority queues
# The default environment is a 1024 vCPU spot cluster
# Priority environment is a 256 vCPU on demand cluster

resource "aws_iam_instance_profile" "nf_ecs_instance_role" {
  name = "openscpca-nf-ecs-instance-role"
  role = aws_iam_role.nf_ecs_role.name
}

# Create an spot instance environment with up to 1024 vcpus

resource "aws_batch_compute_environment" "nf_spot" {
  compute_environment_name = "openscpca-nf-spot-compute"
  compute_resources {
    instance_role = aws_iam_instance_profile.nf_ecs_instance_role.arn
    instance_type = [
      "c4", "m4", "r4",
      "c5", "m5", "r5",
      "c5a", "m5a", "r5a",
      "c6i", "m6i", "r6i",
      "c6a", "m6a", "r6a",
    ]
    allocation_strategy = "SPOT_PRICE_CAPACITY_OPTIMIZED"
    spot_iam_fleet_role = aws_iam_role.nf_spotfleet_role.arn
    bid_percentage      = 60
    max_vcpus           = 1024
    min_vcpus           = 0
    # standard launch template
    launch_template {
      launch_template_id = aws_launch_template.nf_lt_standard.id
      version            = aws_launch_template.nf_lt_standard.latest_version
    }
    security_group_ids = [
      aws_security_group.nf_security.id,
    ]
    subnets = [
      aws_subnet.nf_subnet.id,
    ]
    type = "SPOT"
    tags = {
      parent = "openscpca-nf-spot-compute"
    }
  }

  service_role = aws_iam_role.nf_batch_role.arn
  type         = "MANAGED"
  depends_on   = [aws_iam_role_policy_attachment.nf_batch_role]
}


# Create an ondemand environment with up to 256 vcpus
resource "aws_batch_compute_environment" "nf_ondemand" {
  compute_environment_name = "openscpca-nf-ondemand-compute"
  compute_resources {
    instance_role = aws_iam_instance_profile.nf_ecs_instance_role.arn
    instance_type = [
      "c4", "m4", "r4",
      "c5", "m5", "r5",
      "c5a", "m5a", "r5a",
      "c6i", "m6i", "r6i",
      "c6a", "m6a", "r6a",
    ]
    allocation_strategy = "BEST_FIT"
    max_vcpus           = 256
    min_vcpus           = 0
    # standard launch template
    launch_template {
      launch_template_id = aws_launch_template.nf_lt_standard.id
      version            = aws_launch_template.nf_lt_standard.latest_version
    }
    security_group_ids = [
      aws_security_group.nf_security.id,
    ]
    subnets = [
      aws_subnet.nf_subnet.id,
    ]
    type = "EC2"
    tags = {
      parent = "openscpca-nf-ondemand-compute"
    }

  }
  service_role = aws_iam_role.nf_batch_role.arn
  type         = "MANAGED"
  depends_on   = [aws_iam_role_policy_attachment.nf_batch_role]
}
