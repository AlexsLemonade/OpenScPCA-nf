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
    Version = "2012-10-17"
    Id      = "openscpca-nf-work-key-policy"
    Statement = [
      {
        Sid    = "EnableUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:GenerateDataKey*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowUse"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action = [
          "kms:DescribeKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      # Autoscaling role policies based on https://docs.aws.amazon.com/autoscaling/ec2/userguide/key-policy-requirements-EBS-encryption.html
      {
        Sid    = "AllowServiceRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${local.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
            aws_iam_role.nf_batch_role.arn,
            aws_iam_role.nf_ecs_role.arn,
            aws_iam_role.nf_spotfleet_role.arn
          ]
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
          AWS = [
            "arn:aws:iam::${local.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
            aws_iam_role.nf_batch_role.arn,
            aws_iam_role.nf_ecs_role.arn,
            aws_iam_role.nf_spotfleet_role.arn
          ]
        },
        Action   = "kms:CreateGrant"
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
