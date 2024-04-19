# This sets specific roles for access to AWS services
# used by compute environments and batch queues


### Batch Role
resource "aws_iam_role" "nf_batch_role" {
  name = "openscpca-nf-batch-service-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "batch.amazonaws.com"
        }
      }
    ]
  })

}

resource "aws_iam_role_policy_attachment" "nf_batch_role" {
  role       = aws_iam_role.nf_batch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_iam_role_policy_attachment" "nf_batch_full_access" {
  role       = aws_iam_role.nf_batch_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "batch_kms" {
  role       = aws_iam_role.nf_batch_role.name
  policy_arn = "arn:aws:iam::${local.account_id}:policy/workload-analysis-kms-readwrite"
}

### ECS Role
resource "aws_iam_role" "nf_ecs_role" {
  name = "openscpca-nf-ecs-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_ec2_container" {
  role       = aws_iam_role.nf_ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_rw_s3" {
  role       = aws_iam_role.nf_ecs_role.name
  policy_arn = aws_iam_policy.nf_readwrite_S3.arn
}

resource "aws_iam_role_policy_attachment" "ecs_read_s3" {
  role       = aws_iam_role.nf_ecs_role.name
  policy_arn = aws_iam_policy.nf_read_S3.arn
}

resource "aws_iam_role_policy_attachment" "ecs_auto_scale_ebs" {
  role       = aws_iam_role.nf_ecs_role.name
  policy_arn = aws_iam_policy.nf_manage_ebs.arn
}

resource "aws_iam_role_policy_attachment" "ecs_kms" {
  role       = aws_iam_role.nf_ecs_role.name
  policy_arn = "arn:aws:iam::${local.account_id}:policy/workload-analysis-kms-readwrite"
}


### Spotfleet Role
resource "aws_iam_role" "nf_spotfleet_role" {
  name = "openscpca-nf-spotfleet-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "spotfleet.amazonaws.com"
        }
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "nf_spotfleet_tagging" {
  role       = aws_iam_role.nf_spotfleet_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

resource "aws_iam_role_policy_attachment" "nf_spotfleet_autoscale" {
  role       = aws_iam_role.nf_spotfleet_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetAutoscaleRole"
}

resource "aws_iam_role_policy_attachment" "nf_spotfleet_kms" {
  role       = aws_iam_role.nf_spotfleet_role.name
  policy_arn = "arn:aws:iam::${local.account_id}:policy/workload-analysis-kms-readwrite"
}
