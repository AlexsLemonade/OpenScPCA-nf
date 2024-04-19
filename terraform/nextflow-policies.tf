# Specific policies used by roles and groups
# Which S3 buckets are available for reading

# S3 Group policies taken from AWS Nextflow batch setup

# This policy allows read and write access to specific buckets for nextflow processing
resource "aws_iam_policy" "nf_readwrite_S3" {
  name = "openscpca-nf-readwrite-s3"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "ReadWriteWorkResults"
        Effect = "Allow"
        Action = [
          "s3:GetBucket*",
          "s3:ListBucket*",
          "s3:PutBucket*",
          "s3:GetObject*",
          "s3:PutObject*",
          "s3:DeleteObject*",
          "s3:ReplicateObject",
          "s3:RestoreObject",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
          "s3:GetAccelerateConfiguration",
          "s3:GetAnalyticsConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:GetInventoryConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:GetMetricsConfiguration",
          "s3:PutAccelerateConfiguration",
          "s3:PutAnalyticsConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:PutInventoryConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:PutMetricsConfiguration",
          "s3:PutReplicationConfiguration",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = [
          aws_s3_bucket.nf_work_bucket.arn,
          "${aws_s3_bucket.nf_work_bucket.arn}/*",
          "arn:aws:s3:::openscpca-nf-workflow-results",
          "arn:aws:s3:::openscpca-nf-workflow-results/*",
          "arn:aws:s3:::openscpca-temp-simdata",
          "arn:aws:s3:::openscpca-temp-simdata/*"
        ]
        # },
        # {
        #   Effect = "Allow",
        #   Action = [
        #     "s3:GetAccountPublicAccessBlock",
        #     "s3:ListAllMyBuckets",
        #     "s3:ListAccessPoints",
        #     "s3:HeadBucket"
        #   ]
        #   Resource = "*"
      }
    ]
  })
}


# This policy gives read access to S3 buckets, used for nextflow inputs
resource "aws_iam_policy" "nf_read_S3" {
  name = "openscpca-nf-read-s3"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BucketReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetBucket*",
          "s3:ListBucket*",
          "s3:GetObject*",
          "s3:HeadObject",
          "s3:DescribeJob",
          "s3:GetAccelerateConfiguration",
          "s3:GetAccessPointPolicy*",
          "s3:GetAnalyticsConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:GetInventoryConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:GetMetricsConfiguration",
          "s3:GetReplicationConfiguration"
        ]
        Resource = [
          "arn:aws:s3:::openscpca-data-release", # data release bucket
          "arn:aws:s3:::openscpca-data-release/*",
          "arn:aws:s3:*:*:accesspoint/*",
          "arn:aws:s3:*:*:job/*"
        ]
      },
      {
        Sid    = "BucketListAccess"
        Effect = "Allow"
        Action = [
          "s3:GetAccountPublicAccessBlock",
          "s3:GetAccountPublicAccessBlock",
          "s3:ListAllMyBuckets",
          "s3:ListAccessPoints",
          "s3:ListJobs"
        ]
        Resource = [
          "*"
        ]
      }
    ]
  })
}


resource "aws_iam_policy" "nf_manage_ebs" {
  name        = "openscpca-nf-manage-ebs"
  description = "A policy that allows to manage (attach/create/delete) EBS volumes."
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AttachVolume",
          "ec2:DescribeVolumeStatus",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "ec2:ModifyInstanceAttribute",
          "ec2:DescribeVolumeAttribute",
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:CreateTags"
        ]
        Resource = "*"
      }
    ]
  })
}
