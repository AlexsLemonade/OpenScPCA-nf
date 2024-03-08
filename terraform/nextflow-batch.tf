# AWS Batch setup
provider "aws" {
  region = "us-east-2"
  default_tags {
    tags = {
      team    = "science"
      project = "openscpca"
      purpose = "openscpca-nf-batch"
      config  = "https://github.com/AlexsLemonade/OpenScPCA-nf/terraform"
    }
  }
}


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
    compute_environment = aws_batch_compute_environment.nf_spot.arn
  }
}
