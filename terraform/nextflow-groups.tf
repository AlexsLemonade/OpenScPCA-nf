# This file sets the access settings for the openscpca-nf-batch group
# Currently includes read access to all s3, and write access to select buckets

resource "aws_iam_group" "nf_group" {
  name = "openscpca-nf-batch"
}

# Batch access
resource "aws_iam_group_policy_attachment" "batch_access" {
  group      = aws_iam_group.nf_group.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBatchFullAccess"
}

# EC2 access (may not be needed?)
# resource "aws_iam_group_policy_attachment" "ec2_access" {
#   group      = aws_iam_group.nf_group.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
# }

resource "aws_iam_group_policy_attachment" "read_s3" {
  group      = aws_iam_group.nf_group.name
  policy_arn = aws_iam_policy.nf_read_S3.arn
}

resource "aws_iam_group_policy_attachment" "rw_s3" {
  group      = aws_iam_group.nf_group.name
  policy_arn = aws_iam_policy.nf_readwrite_S3.arn
}
