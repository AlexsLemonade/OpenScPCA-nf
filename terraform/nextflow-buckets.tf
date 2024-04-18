resource "aws_s3_bucket" "nf_work_bucket" {
  bucket = "openscpca-nf-data"
}

resource "aws_s3_bucket_versioning" "nf_work_bucket" {
  bucket = aws_s3_bucket.nf_work_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "nf_work_bucket" {
  bucket = aws_s3_bucket.nf_work_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      # workload-analysis-researcher-s3 key
      kms_master_key_id = aws_kms_key.nf_work_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "nf_work_bucket" {
  bucket = aws_s3_bucket.nf_work_bucket.id
  rule {
    id = "opscpca-nf-expire-work"
    filter {
      prefix = "work/"
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
    expiration {
      days = 30
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
    status = "Enabled"
  }
}
