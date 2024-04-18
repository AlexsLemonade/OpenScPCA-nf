resource "aws_kms_key" "nf_work_key" {
  description = "OpenScPCA Nextflow work bucket key"
}

resource "aws_kms_alias" "nf_work_key" {
  name          = "alias/openscpca-nf-work"
  target_key_id = aws_kms_key.nf_work_key.key_id
}

resource "aws_kms_key_policy" "nf_work_key" {
  key_id = aws_kms_key.nf_work_key.id
  policy = jsonencode({
    Version = "2008-10-17"
    Id      = "example"
    Statement = [
      {
        Sid    = "EnableUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::992382809252:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # Autoscaling role policies based on https://docs.aws.amazon.com/autoscaling/ec2/userguide/key-policy-requirements-EBS-encryption.html
      {
        Sid    = "AllowServiceRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::992382809252:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowServiceRolePersistentAttachment"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::992382809252:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        Action   = "km:CreateGrant"
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      }
    ]
  })
}
