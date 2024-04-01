terraform {
  backend "s3" {
    region  = "us-east-1"
    bucket  = "openscpca-nf-batch-tf"
    key     = "terraform.tfstate"
    encrypt = true
  }
}
