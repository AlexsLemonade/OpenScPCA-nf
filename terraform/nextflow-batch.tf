# AWS Batch setup for Nextflow

resource "aws_batch_job_queue" "nf_default_queue" {
  name     = "openscpca-nf-batch-default-queue"
  state    = "ENABLED"
  priority = 1
  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.nf_spot.arn
  }
}

resource "aws_batch_job_queue" "nf_priority_queue" {
  name     = "openscpca-nf-batch-priority-queue"
  state    = "ENABLED"
  priority = 1
  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.nf_ondemand.arn
  }
}
