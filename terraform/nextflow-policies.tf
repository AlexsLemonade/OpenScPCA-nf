# Specific policies used by roles and groups
# Which S3 buckets are available for reading

# S3 Group policies taken from AWS Nextflow batch setup

# This policy allows read and write access to specific buckets for nextflow processing and output
resource "aws_iam_policy" "nf_readwrite_S3" {
  name = "openscpca-nf-readwrite-s3"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "ReadWriteWorkResults"
        Effect = "Allow",
        Action = [
          "s3:HeadBucket",
          "s3:ListBucket",
          "s3:*Object"
        ]
        Resource = [
          aws_s3_bucket.nf_work_bucket.arn,
          "${aws_s3_bucket.nf_work_bucket.arn}/*",
          "arn:aws:s3:::openscpca-nf-workflow-results",
          "arn:aws:s3:::openscpca-nf-workflow-results/*"
        ]
      }
    ]
  })
}


# This policy gives read access to S3 buckets used for nextflow inputs
resource "aws_iam_policy" "nf_read_S3" {
  name = "openscpca-nf-read-s3"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReleaseBucketReadAccess"
        Effect = "Allow"
        Action = [
          "s3:HeadObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::analysis-s3-992382809252-us-east-2", # current data release bucket
          "arn:aws:s3:::analysis-s3-992382809252-us-east-2/*",
          "arn:aws:s3:::openscpca-data-release", # data release bucket
          "arn:aws:s3:::openscpca-data-release/*"
        ]
      }
    ]
  })
}
