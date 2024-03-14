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
        Effect = "Allow",
        Action = [
          "s3:HeadBucket",
          "s3:ListBucket",
          "s3:*Object"
        ]
        Resource = [
          aws_s3_bucket.nf_work_bucket.arn,
          "${aws_s3_bucket.nf_work_bucket.arn}/*"
          # Need to add the results buckets as well when defined
          # "arn:aws:s3:::openscpca-nf-results/*",
          # "arn:aws:s3:::openscpca-nf-results"
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
  name = "nextflow-ccdl-read-s3"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::analysis-s3-992382809252-us-east-2", # current data release bucket
          "arn:aws:s3:::analysis-s3-992382809252-us-east-2/*"
          # replace with buckets needed for reading when known
          # "arn:aws:s3:::openscpca-data-release/*"
        ]
        # },
        # {
        #   Effect = "Allow"
        #   Action = [
        #     "s3:GetLifecycleConfiguration",
        #     "s3:GetBucketTagging",
        #     "s3:GetInventoryConfiguration",
        #     "s3:ListBucketVersions",
        #     "s3:GetBucketLogging",
        #     "s3:ListBucket",
        #     "s3:GetAccelerateConfiguration",
        #     "s3:GetBucketPolicy",
        #     "s3:GetEncryptionConfiguration",
        #     "s3:GetBucketObjectLockConfiguration",
        #     "s3:GetBucketRequestPayment",
        #     "s3:GetAccessPointPolicyStatus",
        #     "s3:GetMetricsConfiguration",
        #     "s3:GetBucketPublicAccessBlock",
        #     "s3:GetBucketPolicyStatus",
        #     "s3:ListBucketMultipartUploads",
        #     "s3:GetBucketWebsite",
        #     "s3:GetBucketVersioning",
        #     "s3:GetBucketAcl",
        #     "s3:GetBucketNotification",
        #     "s3:GetReplicationConfiguration",
        #     "s3:DescribeJob",
        #     "s3:GetBucketCORS",
        #     "s3:GetAnalyticsConfiguration",
        #     "s3:GetBucketLocation",
        #     "s3:GetAccessPointPolicy"
        #   ]
        #   Resource = [
        #     aws_s3_bucket.nf_work_bucket.arn,
        #     "arn:aws:s3:*:*:accesspoint/*",
        #     "arn:aws:s3:*:*:job/*"
        #     # Add other buckets for reading
        #     # "arn:aws:s3:::openscpca-data-release",
        #     # "arn:aws:s3:::openscpca-nf-results",
        #     #
        #   ]
        # },
        # {
        #   Effect = "Allow",
        #   Action = [
        #     "s3:GetAccessPoint",
        #     "s3:GetAccountPublicAccessBlock",
        #     "s3:ListAllMyBuckets",
        #     "s3:ListAccessPoints",
        #     "s3:ListJobs",
        #     "s3:HeadBucket"
        #   ]
        #   Resource = "*"
      }
    ]
  })
}
